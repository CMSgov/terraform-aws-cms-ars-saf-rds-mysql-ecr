package main

import (
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

// Result a data structure to hold results of the inspec tests
type Result struct {
	Status  string `json:"status"`
	Desc    string `json:"code_desc"`
	Message string `json:"message"`
}

// Control a data structure to hold control related information for a finding
type Control struct {
	ID      string   `json:"id"`
	Title   string   `json:"title"`
	Desc    string   `json:"desc"`
	Tags    Tag      `json:"tags"`
	Results []Result `json:"results"`
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
	for _, result := range control.Results {
		if result.Status != "passed" {
			return processFinding(control, profile, accountID, arn, rdsARN)
		}
	}
	var emptyFinding SecurityHub.AwsSecurityFinding
	return emptyFinding, nil
}

func processFinding(control Control, profile Profile, accountID, arn, rdsARN string) (SecurityHub.AwsSecurityFinding, error) {
	var record SecurityHub.AwsSecurityFinding

	record.AwsAccountId = &accountID
	record.ProductArn = &arn
	record.Title = &control.Title
	record.Description = &control.Desc

	timeStamp := time.Now().UTC().Format("2006-01-02T15:04:05Z07:00")
	record.CreatedAt = &timeStamp
	record.UpdatedAt = &timeStamp

	generatorID := "ecs/inspec/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay"
	record.GeneratorId = &generatorID

	recordID := fmt.Sprintf("%s/%s", rdsARN, control.ID)
	record.Id = &recordID

	// A set of resource data types that describe the resources that the finding
	// refers to.
	resourceType := "AwsRdsDbInstance"
	record.Resources = []*SecurityHub.Resource{
		{
			Id:   &rdsARN,
			Type: &resourceType,
		},
	}

	schemaVersion := "2018-10-08"
	record.SchemaVersion = &schemaVersion

	var findingTypes []*string
	findingTypeStr := "Software and Configuration Checks"
	findingTypes = append(findingTypes, &findingTypeStr)
	record.Types = findingTypes

	severityLabel := strings.ToUpper(control.Tags.Severity)
	record.Severity = &SecurityHub.Severity{
		Label: &severityLabel,
	}

	remediationText := truncateString(control.Tags.Fix, 511)
	record.Remediation = &SecurityHub.Remediation{
		Recommendation: &SecurityHub.Recommendation{
			Text: &remediationText,
		},
	}

	return record, nil
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
			if finding.Id != nil {
				findings = append(findings, &finding)
			}
		}
	}

	if !isDryRun {
		mySession := session.Must(session.NewSession())
		hub := SecurityHub.New(mySession)

		// upload 10 findings at a time to avoid going over max size
		maxPayload := 10
		for start := 0; start < len(findings); start += maxPayload {
			end := start + maxPayload
			if end > len(findings) {
				end = len(findings)
			}
			batchFindings := &SecurityHub.BatchImportFindingsInput{
				Findings: findings[start:end],
			}
			out, importError := hub.BatchImportFindings(batchFindings)
			if importError != nil {
				log.Fatal("failed to upload to security hub", importError.Error())
			}
			fmt.Println(out)
		}
	} else {
		batchFindings := &SecurityHub.BatchImportFindingsInput{
			Findings: findings,
		}
		// out, _ := json.MarshalIndent(&batchFindings, "", "  ")
		// fmt.Println(string(out))
		fmt.Println(batchFindings)
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
