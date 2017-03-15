package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"regexp"
	"syscall"
)

const (
	// NOTE: hardcoded variables, as defined in Dockerfile and in the openresty
	// container used. Should hold true on local machines where openresty is
	// installed at /usr/local/openresty.
	nginxFilePath         string = "/usr/local/openresty/nginx/conf/nginx.conf"
	nginxTemplatePath     string = "/usr/local/openresty/nginx/conf/nginx.conf.template"
	luaScriptPath         string = "/usr/local/openresty/nginx/conf/nginx.lua"
	luaScriptTemplatePath string = "/usr/local/openresty/nginx/conf/nginx.lua.template"
)

var (
	openrestyCmd []string = []string{"/usr/local/openresty/nginx/sbin/nginx", "-c",
		nginxFilePath}
)

// context struct stores the user input and the constraints for the specified
// input. It also stores the keyword that needs to be replaced in the template
// files.
type context struct {
	cliInput        string
	templateKeyword string
	regex           string
}

// sanity function takes the pre-defined constraints and the user inputs as
// arguments and validates user input based on regex matching
func sanity(input map[string]*context) error {
	var format *regexp.Regexp
	for _, ctx := range input {
		format = regexp.MustCompile(ctx.regex)
		if format.MatchString(ctx.cliInput) == false {
			return errors.New(fmt.Sprintf(
				"Invalid value: '%s' for '%s'. Can be %s",
				ctx.cliInput,
				ctx.templateKeyword,
				ctx.regex))
		}
	}
	return nil
}

// createFile function takes the pre-defined keywords, user inputs, the
// template file path and the new file path location as parameters, and
// creates a new file at file path with all the keywords replaced by inputs.
func createFile(input map[string]*context,
	template string, conf string) error {
	// read the template
	contents, err := ioutil.ReadFile(template)
	if err != nil {
		log.Fatal(err)
	}
	// replace
	for _, ctx := range input {
		contents = bytes.Replace(contents, []byte(ctx.templateKeyword),
			[]byte(ctx.cliInput), -1)
	}
	// write
	err = ioutil.WriteFile(conf, contents, 0644)
	if err != nil {
		log.Fatal(err)
	}
	return nil
}

func main() {
	//TODO: Better regexes for port numbers and dns names
	hostRegex := `[a-z0-9.]+`
	portRegex := `[0-9]{1,5}`
	// input holds the map of context structs while processing the template
	// for search and replace
	input := make(map[string]*context)

	input["upstream-api-port"] = &context{}
	input["upstream-api-port"].regex = portRegex
	input["upstream-api-port"].templateKeyword = "UPSTREAM_API_PORT"
	flag.StringVar(&input["upstream-api-port"].cliInput,
		"upstream-api-port",
		"",
		"port where 3scale can connect to the proxy to verify the health of"+
			" the self-hosted deployment. Also the port at which nginx proxy"+
			" listens for requests to the cluster. ")

	input["upstream-bdb-host"] = &context{}
	input["upstream-bdb-host"].regex = hostRegex
	input["upstream-bdb-host"].templateKeyword = "UPSTREAM_BDB_HOST"
	flag.StringVar(&input["upstream-bdb-host"].cliInput,
		"upstream-bdb-host",
		"",
		"host name/ip of the bdb instance")

	input["upstream-bdb-port"] = &context{}
	input["upstream-bdb-port"].regex = portRegex
	input["upstream-bdb-port"].templateKeyword = "UPSTREAM_BDB_PORT"
	flag.StringVar(&input["upstream-bdb-port"].cliInput,
		"upstream-bdb-port",
		"",
		"port number of the bdb instance")

	input["frontend-api-port"] = &context{}
	input["frontend-api-port"].regex = portRegex
	input["frontend-api-port"].templateKeyword = "FRONTEND_API_PORT"
	flag.StringVar(&input["frontend-api-port"].cliInput,
		"frontend-api-port",
		"",
		"port number exposed to the external world for accessing the backend"+
			" BDB services")

	input["frontend-api-dns-name"] = &context{}
	input["frontend-api-dns-name"].regex = hostRegex
	input["frontend-api-dns-name"].templateKeyword = "FRONTEND_DNS_NAME"
	flag.StringVar(&input["frontend-api-dns-name"].cliInput,
		"frontend-api-dns-name",
		"",
		"globally unique dns/ip used byt the external world for accessing"+
			" backend BDB services")

	input["provider-key"] = &context{}
	input["provider-key"].regex = `[a-z0-9]{32}`
	input["provider-key"].templateKeyword = "PROVIDER_KEY"
	flag.StringVar(&input["provider-key"].cliInput,
		"provider-key",
		"",
		"3scale provider key")

	input["3scale-version-header"] = &context{}
	input["3scale-version-header"].regex = `[0-9TZ:-]+`
	input["3scale-version-header"].templateKeyword = "3SCALE_VERSION_HEADER"
	flag.StringVar(&input["3scale-version-header"].cliInput,
		"3scale-version-header",
		"",
		"3scale/nginx version header")

	input["3scale-service-id"] = &context{}
	input["3scale-service-id"].regex = `[0-9]{13}`
	input["3scale-service-id"].templateKeyword = "SERVICE_ID"
	flag.StringVar(&input["3scale-service-id"].cliInput,
		"3scale-service-id",
		"",
		"3scale service id")

	input["3scale-secret-token"] = &context{}
	input["3scale-secret-token"].regex = `[a-z0-9]+`
	input["3scale-secret-token"].templateKeyword = "3SCALE_RESPONSE_SECRET_TOKEN"
	flag.StringVar(&input["3scale-secret-token"].cliInput,
		"3scale-secret-token",
		"",
		"secret response token set in 3scale to validate 3scale requests")

	input["health-check-port"] = &context{}
	input["health-check-port"].regex = portRegex
	input["health-check-port"].templateKeyword = "HEALTH_CHECK_PORT"
	flag.StringVar(&input["health-check-port"].cliInput,
		"health-check-port",
		"",
		"port number for LB health check")
	flag.Parse()
	err := sanity(input)
	if err != nil {
		log.Fatal(err)
	}

	// create the files using the templates
	createFile(input, nginxTemplatePath, nginxFilePath)
	createFile(input, luaScriptTemplatePath, luaScriptPath)

	// start openresty
	err = syscall.Exec(openrestyCmd[0], openrestyCmd[0:], os.Environ())
	if err != nil {
		panic(err)
	}
}
