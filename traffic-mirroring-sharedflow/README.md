# Traffic Mirroring Shared Flow

This sample demonstrates how to use an Apigee shared flow to mirror (shadow) HTTP requests to a secondary endpoint for testing purposes without impacting the primary API response. This pattern is commonly used during API migrations, A/B testing, and canary deployments.

## About Traffic Mirroring

Traffic mirroring, also known as "shadow traffic" or "dark traffic", is a technique where production traffic is duplicated and sent to a secondary endpoint for testing or validation purposes. The key characteristics are:

- **Non-blocking**: The mirrored request does not block or delay the primary request
- **Fire-and-forget**: The response from the mirrored endpoint is not returned to the client
- **Zero impact**: Errors in the mirrored endpoint do not affect the primary response
- **Production validation**: Test new implementations with real production traffic

## Use Cases

This shared flow is useful for:

1. **API Migration Testing**: Validate a new API version or implementation before cutover
2. **Performance Comparison**: Compare response times between old and new systems
3. **Blue-Green Deployments**: Test the "green" environment with production traffic before switching
4. **Canary Releases**: Validate new code with a subset of real traffic
5. **Legacy System Retirement**: Verify new microservices match legacy monolith behavior
6. **Load Testing**: Generate realistic load on new infrastructure

## How It Works

The shared flow uses two policies:

1. **AM-SetTarget**: Configures the mirror destination host and URL
2. **SC-RequestMirror**: Makes a ServiceCallout to the mirror endpoint

All policies use `continueOnError="true"` to ensure failures in the mirror request don't impact the primary flow.

**Non-Blocking Implementation:** The mirror is executed in the `PostClientFlow`, which runs *after* the client response has been sent. This ensures zero latency impact on the primary request - it's a true fire-and-forget pattern.

### Architecture

```sh
Client Request → Apigee Proxy → Primary Backend → Response to Client
                                                          ↓
                                                   PostClientFlow
                                                          ↓
                                                   Shared Flow (Mirror)
                                                          ↓
                                                   Mirror Endpoint
                                                   (fire-and-forget)
```

## Prerequisites

1. [Provision Apigee X](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro)
2. Configure [external access](https://cloud.google.com/apigee/docs/api-platform/get-started/configure-routing#external-access) for API traffic to your Apigee X instance
3. Access to deploy shared flows and proxies in Apigee
4. Make sure the following tools are available in your terminal's $PATH (Cloud Shell has these preconfigured)
   - [gcloud SDK](https://cloud.google.com/sdk/docs/install)
   - curl
   - jq
   - [apigeecli](https://github.com/apigee/apigeecli)

## (QuickStart) Setup using CloudShell

Use the following GCP CloudShell tutorial, and follow the instructions.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/apigee-samples&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=traffic-mirroring-sharedflow/docs/cloudshell-tutorial.md)

## Setup Instructions

1. Clone the `apigee-samples` repo, and switch to the `traffic-mirroring-sharedflow` directory

   ```bash
   git clone https://github.com/GoogleCloudPlatform/apigee-samples.git
   cd apigee-samples/traffic-mirroring-sharedflow
   ```

2. Edit `env.sh` and configure the following variables:

   - `PROJECT` - the project where your Apigee organization is located
   - `APIGEE_HOST` - the externally reachable hostname of the Apigee environment group
   - `APIGEE_ENV` - the Apigee environment where resources should be created

   Now source the `env.sh` file:

   ```bash
   source ./env.sh
   ```

3. Deploy the shared flow and example proxy

   ```bash
   ./deploy-traffic-mirroring.sh
   ```

   This script will:
   - Install apigeecli if not present
   - Deploy the `traffic-mirroring` shared flow
   - Deploy an example proxy that demonstrates the usage

## Configuration

To use the shared flow in your API proxy, you need to:

### 1. Add a FlowCallout Policy

Create a FlowCallout policy in your proxy:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<FlowCallout name="FC-TrafficMirror">
  <DisplayName>FC-TrafficMirror</DisplayName>
  <SharedFlowBundle>traffic-mirroring</SharedFlowBundle>
</FlowCallout>
```

### 2. Set Required Variables

Before calling the shared flow, set these variables using an AssignMessage policy:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<AssignMessage name="AM-ConfigureMirror">
  <DisplayName>AM-ConfigureMirror</DisplayName>
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
```

### 3. Add to Your Proxy Flow

Add the configuration policy to your proxy's PreFlow (request), and the FlowCallout to the PostClientFlow (response). This ensures the mirror executes *after* the client response is sent:

```xml
<PreFlow>
  <Request>
    <Step>
      <Name>AM-ConfigureMirror</Name>
    </Step>
  </Request>
</PreFlow>

<PostClientFlow>
  <Response>
    <Step>
      <Name>FC-TrafficMirror</Name>
    </Step>
  </Response>
</PostClientFlow>
```

**Key Point:** By placing the FlowCallout in `PostClientFlow`, the mirroring happens asynchronously after the client has already received their response. This guarantees zero latency impact.

### Variable Reference

| Variable                | Required | Description                                   | Example                        |
|-------------------------|----------|-----------------------------------------------|--------------------------------|
| `request-mirror-host`   | Yes      | Host header for the mirror endpoint           | `api-test.example.com`         |
| `request-mirror-target` | Yes      | Full base URL of the mirror endpoint          | `https://api-test.example.com` |
| `request-mirror-uri`    | Yes      | Path to mirror (usually `{proxy.pathsuffix}`) | `/v1/users`                    |

**Note:** Since the mirror executes in `PostClientFlow` (after the client response is sent), the mirror response is not captured or returned to the client. This is intentional for the fire-and-forget pattern. For debugging, use analytics, message logging policies, or target server logs.

## Example Proxy

The sample includes an example API proxy (`example-proxy/`) that demonstrates the traffic mirroring pattern. This proxy:

- **Endpoint**: `/v1/samples/traffic-mirror`
- **Primary Backend**: `https://httpbin.org` - returns the response to the client
- **Mirror Endpoint**: `https://httpbin.org/delay/2` - receives mirrored traffic asynchronously

The example proxy shows:
1. How to configure mirror variables in PreFlow using `AM-ConfigureMirror`
2. How to invoke the shared flow in PostClientFlow using `FC-TrafficMirror`
3. Zero-latency implementation - the 2-second delay on the mirror endpoint does not impact client response time

### Example Proxy Structure

```
example-proxy/
├── apiproxy/
│   ├── policies/
│   │   ├── AM-ConfigureMirror.xml    # Sets mirror configuration variables
│   │   └── FC-TrafficMirror.xml      # Calls the traffic-mirroring shared flow
│   ├── proxies/
│   │   └── default.xml               # Proxy endpoint with PostClientFlow
│   └── targets/
│       └── default.xml               # Primary backend target
```

## Testing the Sample

After deployment, test the example proxy:

```bash
# Test the proxy
curl -i https://${APIGEE_HOST}/v1/samples/traffic-mirror/get

# The mirror request is sent to httpbin.org in the background
# Check target server logs or Apigee analytics to verify mirror traffic
```

You can also run the automated test suite:

```bash
npm run test
```

## Advanced Usage

### Conditional Mirroring

Mirror only specific requests using conditions:

```xml
<Step>
  <Name>FC-TrafficMirror</Name>
  <Condition>request.header.x-enable-mirror = "true"</Condition>
</Step>
```

### Percentage-based Mirroring

Mirror only a percentage of traffic:

```xml
<!-- Generate random number 0-99 -->
<AssignMessage name="AM-GenerateRandom">
  <AssignVariable>
    <Name>random.number</Name>
    <Value>{randomLong(100)}</Value>
  </AssignVariable>
</AssignMessage>

<!-- Mirror only 10% of traffic -->
<Step>
  <Name>FC-TrafficMirror</Name>
  <Condition>random.number &lt; 10</Condition>
</Step>
```

### Different Mirror Paths

Send mirrored traffic to a different path:

```xml
<AssignVariable>
  <Name>request-mirror-uri</Name>
  <Value>/v2{proxy.pathsuffix}</Value>
</AssignVariable>
```

## Best Practices

1. **Monitor Mirror Endpoint**: Although errors don't impact the main flow, monitor the mirror endpoint for issues using target server logs or analytics
2. **Use Conditions**: Only mirror when needed to reduce unnecessary load
3. **Set Timeouts**: The ServiceCallout has a default timeout; adjust if needed in the policy configuration
4. **Security**: Ensure mirror endpoint can handle production data securely
5. **Zero Latency**: Because mirroring happens in PostClientFlow, there's no performance impact on the client response

## Troubleshooting

### Mirror requests not sent

- Check that `request-mirror-host` variable is set
- Verify the condition on the FlowCallout step
- Check Apigee trace to see if policies execute

### Mirror endpoint unreachable

- Verify mirror endpoint URL and firewall rules
- Check ServiceCallout timeout settings
- Review Apigee message logs

### High latency

- Although async, ServiceCallout adds minimal overhead
- Consider using conditions to reduce mirror frequency
- Check if mirror endpoint is slow to respond

## Cleanup

To remove the sample from your Apigee organization:

```bash
source ./env.sh
./clean-up-traffic-mirroring.sh
```

## Related Resources

- [Apigee ServiceCallout Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/service-callout-policy)
- [Apigee Shared Flows](https://cloud.google.com/apigee/docs/api-platform/fundamentals/shared-flows)
- [FlowCallout Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/flow-callout-policy)
- [Strangler Fig Pattern](https://martinfowler.com/bliki/StranglerFigApplication.html)

## License

All solutions within this repository are provided under the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) license. Please see the [LICENSE](../LICENSE.txt) file for more detailed terms and conditions.

## Not Google Product Clause

This is not an officially supported Google product, nor is it part of an official Google product.
