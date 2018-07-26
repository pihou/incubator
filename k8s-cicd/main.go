package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"fmt"
	"github.com/codegangsta/cli"
	_ "github.com/joho/godotenv/autoload"
	_ "io"
	"log"
	"net/http"
	"os"
	"strings"
)

const jsonPatch = `{"spec":{"template":{"spec":{"containers":[{"name":"%s","image":"%s:%s"}]}}}}`
const kubePath = "/apis/apps/v1/namespaces/%s/deployments/%s"

func updateKube(c *cli.Context) {
	kubeHost := c.String("kubernetes.server")
	userToken := c.String("kubernetes.token")
	serverCert := c.String("kubernetes.cert")

	namespace := c.String("namespace")
	deployment := c.String("deployment")
	container := c.String("container")
	imageName := c.String("image.name")
	imageTag := c.String("image.tag")

	path := fmt.Sprintf(kubePath, namespace, deployment)
	json := fmt.Sprintf(jsonPatch, container, imageName, imageTag)
	cert, err := base64.StdEncoding.DecodeString(serverCert)
	if err != nil {
		log.Println("Decode server certificate error", err)
		return
	}
	rootCAs, _ := x509.SystemCertPool()
	if rootCAs == nil {
		rootCAs = x509.NewCertPool()
	}
	if ok := rootCAs.AppendCertsFromPEM(cert); !ok {
		log.Println("No certs appended, using system certs only")
	}
	config := &tls.Config{RootCAs: rootCAs}
	trport := &http.Transport{TLSClientConfig: config}
	client := &http.Client{Transport: trport}

	request, err := http.NewRequest("PATCH", kubeHost+path, strings.NewReader(json))
	if err != nil {
		log.Println("New http reqeust error", err)
		return
	}
	request.Header.Add("Authorization", "Bearer "+userToken)
	request.Header.Add("Content-Type", "application/strategic-merge-patch+json")
	response, err := client.Do(request)
	if err != nil {
		log.Println("Request Error", err)
		return
	}
	log.Printf("Request status:%s\n", response.Status)
}

func main() {
	log.SetFlags(log.Ldate | log.Ltime | log.Llongfile)
	app := cli.NewApp()
	app.Name = "kubernetes CI/CD"
	app.Usage = "update kubernetes deployment"
	app.Action = updateKube
	app.Version = "0.0.1"
	app.Flags = []cli.Flag{
		cli.StringFlag{
			Name:   "namespace",
			Usage:  "the namespace you operate",
			EnvVar: "PLUGIN_NAMESPACE",
		},
		cli.StringFlag{
			Name:   "deployment",
			Usage:  "the deployment name you want to update",
			EnvVar: "PLUGIN_DEPLOYMENT",
		},
		cli.StringFlag{
			Name:   "container",
			Usage:  "the container name",
			EnvVar: "PLUGIN_CONTAINER",
		},
		cli.StringFlag{
			Name:   "image.name",
			Usage:  "the image name include repository",
			EnvVar: "PLUGIN_IMAGE_NAME",
		},
		cli.StringFlag{
			Name:   "image.tag",
			Usage:  "the image tag",
			EnvVar: "PLUGIN_IMAGE_TAG",
		},
		cli.StringFlag{
			Name:   "kubernetes.server",
			Usage:  "kubernetes server url",
			EnvVar: "PLUGIN_KUBERNETES_SERVER",
		},
		cli.StringFlag{
			Name:   "kubernetes.cert",
			Usage:  "kubernetes server certificate authority",
			EnvVar: "PLUGIN_KUBERNETES_CERT",
		},
		cli.StringFlag{
			Name:   "kubernetes.token",
			Usage:  "kubernetes user token",
			EnvVar: "PLUGIN_KUBERNETES_TOKEN",
		},
	}
	app.Run(os.Args)
}
