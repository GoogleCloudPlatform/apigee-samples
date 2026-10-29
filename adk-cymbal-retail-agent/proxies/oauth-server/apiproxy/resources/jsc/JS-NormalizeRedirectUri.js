var qUri = context.getVariable("request.queryparam.redirect_uri");
if (qUri) {
  if (qUri.indexOf(".cloudshell.dev") !== -1) {
    context.setVariable("cloudshell_redirect_uri", qUri);
    context.setVariable("normalized_redirect_uri", "http://localhost:9000/callback");
    context.setVariable("request.queryparam.redirect_uri", "http://localhost:9000/callback");
  } else {
    context.setVariable("normalized_redirect_uri", qUri);
  }
}
var fUri = context.getVariable("request.formparam.redirect_uri");
if (fUri) {
  if (fUri.indexOf(".cloudshell.dev") !== -1) {
    context.setVariable("normalized_redirect_uri", "http://localhost:9000/callback");
    context.setVariable("request.formparam.redirect_uri", "http://localhost:9000/callback");
  } else {
    context.setVariable("normalized_redirect_uri", fUri);
  }
}
