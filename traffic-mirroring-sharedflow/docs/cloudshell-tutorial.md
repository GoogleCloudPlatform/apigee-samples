# Traffic Mirroring Shared Flow

---
**Time to complete**: About 10 minutes

Click the **Start** button to move to the next step.

---

## Setup environment

Edge scripts require information from you to operate correctly. You'll need to supply:

* Your Google Cloud Project ID
* Your Apigee environment name
* Your Apigee environment group hostname

---

## Configure

Now let's configure the environment variables required by the setup script.

```sh
export PROJECT=<walkthrough-project-id/>
```

```sh
export APIGEE_HOST=APIGEE_HOSTNAME
```

```sh
export APIGEE_ENV=APIGEE_ENVIRONMENT
```

---

## Deploy Traffic Mirroring Shared Flow

Next, let's deploy both the shared flow and example proxy.

```sh
./deploy-traffic-mirroring.sh
```

This script deploys:

1. The `traffic-mirroring` shared flow
2. An example proxy that demonstrates usage

The deployment uses the `apigeecli` tool to bundle and deploy to your Apigee organization.

---

## Test the Deployment

Now let's test the deployed proxy to see traffic mirroring in action.

Make a request to the example proxy:

```sh
curl https://$APIGEE_HOST/v1/samples/traffic-mirror/get
```

Notice:

* The response comes from the primary backend (httpbin.org)
* The response is fast, even though the mirror endpoint has a 2-second delay (mirror happens in background)
* No mirror-related headers appear in the response (fire-and-forget pattern)

This demonstrates that the mirror request is truly non-blocking. The mirroring happens in `PostClientFlow`, which executes *after* the client response is sent, ensuring zero latency impact.

---

## Understanding the Implementation

The shared flow uses two key policies:

1. **AM-SetTarget**: Configures the mirror destination
2. **SC-RequestMirror**: Makes a ServiceCallout to the mirror endpoint

All policies use `continueOnError="true"` to ensure mirror failures don't affect the main request.

**Non-Blocking Design**: The mirror executes in `PostClientFlow`, which runs after the client response is sent. This ensures zero latency impact - it's a true fire-and-forget pattern.

---

## View in Apigee Console

You can view the deployed resources in the Apigee console:

* [Shared Flows](https://apigee.google.com/platform/<walkthrough-project-id/>/develop/sharedflows)
* [API Proxies](https://apigee.google.com/platform/<walkthrough-project-id/>/proxies)

Navigate to **Develop > Shared Flows** to see the `traffic-mirroring` shared flow.

Navigate to **Develop > API Proxies** to see the `traffic-mirror-example` proxy.

---

## Run Integration Tests

The sample includes automated integration tests. Let's run them:

Run the integration tests:

```sh
npm run test
```

The tests verify:

* The proxy responds successfully
* The response is fast (non-blocking)

---

## Use in Your Own Proxies

To use the traffic mirroring shared flow in your own proxies:

1. Add a FlowCallout policy that references `traffic-mirroring`
2. Set these variables before calling the shared flow:
   * `request-mirror-host`: Host header for mirror endpoint
   * `request-mirror-target`: Base URL of mirror endpoint
   * `request-mirror-uri`: Path to mirror

Example:

```xml
<AssignMessage name="AM-ConfigureMirror">
  <AssignVariable>
    <Name>request-mirror-host</Name>
    <Value>api-test.example.com</Value>
  </AssignVariable>
  <AssignVariable>
    <Name>request-mirror-target</Name>
    <Value>https://api-test.example.com</Value>
  </AssignVariable>
  <AssignVariable>
    <Name>request-mirror-uri</Name>
    <Value>{proxy.pathsuffix}</Value>
  </AssignVariable>
</AssignMessage>

<FlowCallout name="FC-TrafficMirror">
  <SharedFlowBundle>traffic-mirroring</SharedFlowBundle>
</FlowCallout>
```

---

## Cleanup

If you want to clean up the artifacts from this sample:

```sh
./clean-up-traffic-mirroring.sh
```

This will undeploy and delete both the shared flow and example proxy.

---

## Conclusion

Congratulations! You've successfully deployed and tested the Traffic Mirroring Shared Flow.

**What you learned:**

* How to mirror production traffic for testing
* How to use Apigee shared flows
* How to make non-blocking ServiceCallout requests
* Best practices for API migration testing

**Next Steps:**

* Use this pattern for your own API migrations
* Explore conditional mirroring (percentage-based, header-based)
* Add monitoring and logging for mirror endpoints

For more information, visit the [Apigee documentation](https://cloud.google.com/apigee/docs).
