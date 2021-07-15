package main

import (
	"github.com/aws/aws-sdk-go/aws/credentials/stscreds"
	"github.com/aws/aws-sdk-go/aws/session"
	SecurityHub "github.com/aws/aws-sdk-go/service/securityhub"

	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"
)

// ScanResult a resource related to inSpec/cinc scan results.
type ScanResult struct {
	Profiles []Profile `json:"profiles"`
}

// Tag a data structure to hold tag related information for a finding
type Tag struct {
	Severity string `json:"severity"`
	CisID    string `json:"cis_id"`
	CisLevel int    `json:"cis_level"`
	Check    string `json:"check"`
	Fix      string `json:"fix"`
}

// Profile a data structure to hold profile data for an inSpec/cinc scan result
type Profile struct {
	Name       string    `json:"name"`
	Maintainer string    `json:"maintainer"`
	Summary    string    `json:"summary"`
	License    string    `json:"license"`
	Controls   []Control `json:"controls"`
}

// Control a data structure to hold control related information for a finding
type Control struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Desc  string `json:"desc"`
	Tags  Tag    `json:"tags"`
}

// severityToCriticality expects a string with severity and returns a int representation of it.
//    * 0 - INFORMATIONAL
//
//    * 1–39 - LOW
//
//    * 40–69 - MEDIUM
//
//    * 70–89 - HIGH
//
//    * 90–100 - CRITICAL
func severityToCriticality(severity string) int64 {
	switch strings.ToLower(severity) {
	case "informational":
		return 0
	case "low":
		return 39
	case "medium":
		return 69
	case "high":
		return 89
	case "critical":
		return 100
	default:
		return 0
	}
}

func truncateString(val string, maxLength int) string {
	if len(val) > maxLength {
		trimmedVal := val[0:maxLength]
		return trimmedVal
	}
	return val
}

// GenerateSecurityHubFinding expects a inspec json object and returns a new security hub finding.
func GenerateSecurityHubFinding(control Control, profile Profile, accountID, arn, rdsARN string) (SecurityHub.AwsSecurityFinding, error) {
	var SecurityHubGenerator = "ecs/inspec/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay"
	var ResourceType = "AwsRdsDbInstance"
	var Resource = SecurityHub.Resource{
		Id:   &rdsARN,
		Type: &ResourceType,
	}
	productFields := make(map[string]*string)
	productFields["ProviderName"] = &SecurityHubGenerator

	var ResourceList []*SecurityHub.Resource
	var schemaVersion = "2018-10-08"
	var record SecurityHub.AwsSecurityFinding
	criticality := severityToCriticality(control.Tags.Severity)
	timeStamp := time.Now().UTC().Format("2006-01-02T15:04:05Z07:00")
	findingStatus := "ACTIVE"
	ResourceList = append(ResourceList, &Resource)
	remediationText := truncateString(control.Tags.Fix, 511)
	var findingTypes []*string
	findingTypeStr := "Software and Configuration Checks/CIS/RDS/mysql"
	severityLabel := strings.ToUpper(control.Tags.Severity)
	findingTypes = append(findingTypes, &findingTypeStr)
	providerFields := SecurityHub.FindingProviderFields{
		Confidence:  &criticality,
		Criticality: &criticality,
		Severity: &SecurityHub.FindingProviderSeverity{
			Label: &severityLabel,
		},
		Types: findingTypes,
	}

	record.AwsAccountId = &accountID
	record.CreatedAt = &timeStamp
	record.Description = &control.Desc
	record.FindingProviderFields = &providerFields
	record.GeneratorId = &SecurityHubGenerator
	record.Id = &control.ID
	// The ARN generated by Security Hub that uniquely identifies a product that
	// generates findings. This can be the ARN for a third-party product that is
	// integrated with Security Hub, or the ARN for a custom integration.
	record.ProductArn = &arn
	// A set of resource data types that describe the resources that the finding
	// refers to.
	record.Resources = ResourceList
	record.SchemaVersion = &schemaVersion
	//record.Types		 = *["Software and Configuration Checks/Vulnerabilities/CVE with InSpec profile"]
	record.RecordState = &findingStatus
	record.Severity = &SecurityHub.Severity{
		Label: &severityLabel,
	}

	record.ProductFields = productFields
	record.Title = &control.Title
	record.Types = findingTypes
	record.UpdatedAt = &timeStamp
	record.Criticality = &criticality
	record.Remediation = &SecurityHub.Remediation{
		Recommendation: &SecurityHub.Recommendation{
			Text: &remediationText,
		},
	}
	return record, nil
}

// MakeSession sets up a session to AWS
func MakeSession() (*session.Session, error) {
	sessOpts := session.Options{
		SharedConfigState:       session.SharedConfigEnable,
		AssumeRoleTokenProvider: stscreds.StdinTokenProvider,
	}
	return session.NewSessionWithOptions(sessOpts)
}

// ProcessFindingsIntoSecurityHub takes the profiles data structure and converts it to security hub findings before registering them
func ProcessFindingsIntoSecurityHub(profiles []Profile, isDryRun bool, accountID, arn, rdsARN string) error {
	var findings []*SecurityHub.AwsSecurityFinding

	for _, profile := range profiles {
		for _, control := range profile.Controls {
			// convert inspec finding into security hub finding
			finding, err := GenerateSecurityHubFinding(control, profile, accountID, arn, rdsARN)
			if err != nil {
				return err
			}
			findings = append(findings, &finding)
		}
	}

	if !isDryRun {
		// https://docs.aws.amazon.com/sdk-for-go/api/aws/session/
		// Create new session and assume the role of ECS task runner
		// By default the SDK will only load the shared credentials file's (~/.aws/credentials) credentials values,
		// and all other config is provided by the environment variables, SDK defaults, and user provided aws.Config values.
		sess := session.Must(MakeSession())

		hub := SecurityHub.New(sess)
		// upload 10 findings at a time to avoid going over max size
		maxPayload := 10
		for count := 0; count < len(findings); count = count + maxPayload {
			batchFindings := &SecurityHub.BatchImportFindingsInput{
				Findings: findings[count : count+maxPayload],
			}
			out, importError := hub.BatchImportFindings(batchFindings)
			if importError != nil {
				return importError
			}
			fmt.Println(out)
		}
	} else {
		for _, find := range findings {
			fmt.Println(find)
		}
	}
	return nil
}

func main() {
	// read flag values
	isDryRun := flag.Bool("dry", true, "Dry run, without uploading findings into security hub")
	accountID := flag.String("accountid", "", "The AWS account ID that a finding is generated in")
	// The ARN generated by Security Hub that uniquely identifies a product that
	// generates findings. This can be the ARN for a third-party product that is
	// integrated with Security Hub, or the ARN for a custom integration.
	arn := flag.String("product-arn", "", "ARN for this custom integration")
	rdsARN := flag.String("rds-arn", "", "ARN of the RDS instance scanned")

	flag.Parse()

	var result ScanResult
	dec := json.NewDecoder(os.Stdin)
	for {
		err := dec.Decode(&result)
		if err != nil {
			if err == io.EOF {
				break // reached end of file, exit loop
			}
			log.Fatal("failed to parse json stream", err)
		}
	}
	if len(result.Profiles) < 1 {
		log.Fatal("No profiles found in stream:")
	}
	err := ProcessFindingsIntoSecurityHub(result.Profiles, *isDryRun, *accountID, *arn, *rdsARN)
	if err != nil {
		log.Fatal("failed to process findings", err)
	}
}
