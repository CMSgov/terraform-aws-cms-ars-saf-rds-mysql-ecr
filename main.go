package main

import (
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/securityhub"

	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
)


type ScanResult struct {
	Profiles []Profile `json:"profiles"`
}

type Profile struct {
	Name string `json:"name"`
	Maintainer string `json:"maintainer"`
	Summary string `json:"summary"`
	License string `json:"license"`
	Controls []Control `json:"controls"`
}

type Control struct {
	Id string `json:"id"`
	Title string `json:"title"`
}

// GenerateSecurityHubFinding expects a inspec json object and returns a new security hub finding.
func GenerateSecurityHubFinding(control Control, profile Profile) {

}

func PushFindingsIntoSecurityHub(profiles []Profile) error {
	// https://docs.aws.amazon.com/sdk-for-go/api/aws/session/
	// Create new session and assume the role of ECS task runner
	// By default the SDK will only load the shared credentials file's (~/.aws/credentials) credentials values,
	// and all other config is provided by the environment variables, SDK defaults, and user provided aws.Config values.

	// If the AWS_SDK_LOAD_CONFIG environment variable is set,
	// or SharedConfigEnable option is used to create the Session the full shared config values will be loaded.
	// This includes credentials, region, and support for assume role.
	// In addition the Session will load its configuration from both the shared config file (~/.aws/config)
	// and shared credentials file (~/.aws/credentials). Both files have the same format.
	sess, err := session.NewSessionWithOptions(session.Options{
		SharedConfigState: session.SharedConfigEnable,
		Config: aws.Config{
			Region: aws.String("us-west-2"),


		},
	})
	if err != nil {
		return err
	}

	securityhub := securityhub.New(sess)
	for _, profile := range profiles {
		for _, control := range profile.Controls {
			// convert inspec finding into security hub finding

			// then import finding into security hub
			// https://docs.aws.amazon.com/securityhub/latest/userguide/finding-update-batchimportfindings.html
		}
	}
}

func main() {
	region:= flag.String("region", "", "AWS Region")

	//check for region flag, cannot be empty
	if *region == "" {
		log.Fatal("region argument was not provided or is empty")
	}


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
	for _, profile := range result.Profiles {
		fmt.Println(profile.Name)
		fmt.Println(len(profile.Controls))
	}
}