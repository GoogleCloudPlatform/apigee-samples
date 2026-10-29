var csUri = context.getVariable("cloudshell_redirect_uri");
var loc = context.getVariable("response.header.Location");
if (csUri && loc && loc.indexOf("http://localhost:9000/callback") === 0) {
  var suffix = loc.substring("http://localhost:9000/callback".length);
  context.setVariable("response.header.Location", csUri + suffix);
}
