// List of predefined API path patterns using * as wildcard
var allowedPaths = context.getVariable("allowedPaths");
var API_PATHS = allowedPaths.split(',');

/**
 * Finds the matching pattern for a given path
 * @param {string} inputPath - The path to match against predefined patterns
 * @param {Array<string>} patterns - Array of path patterns to match against
 * @returns {string|null} The matching pattern or null if no match found
 */
function findMatchingPattern(inputPath, patterns) {
    // Normalize the input path
    inputPath = inputPath.trim();
    
    // First try exact match for better performance
    if (patterns.indexOf(inputPath) !== -1) {
        return inputPath;
    }
    
    // Split paths into segments
    var inputSegments = inputPath.split('/');
    
    // Find matching pattern
    for (var i = 0; i < patterns.length; i++) {
        var pattern = patterns[i];
        var patternSegments = pattern.split('/');
        
        // Skip if segments length doesn't match
        if (inputSegments.length !== patternSegments.length) {
            continue;
        }
        
        var matches = true;
        for (var j = 0; j < patternSegments.length; j++) {
            // Skip empty segments (from leading slash)
            if (patternSegments[j] === '') continue;
            
            // If pattern segment is *, any input segment matches
            // Otherwise, segments must match exactly
            if (patternSegments[j] !== '*' && 
                patternSegments[j] !== inputSegments[j]) {
                matches = false;
                break;
            }
        }
        
        if (matches) {
            return pattern;
        }
    }
    
    return null;
}


// Example usage
var path = context.getVariable("proxy.pathsuffix");
var matchingPattern = findMatchingPattern(path, API_PATHS);
print('Input path:', path);
print('Matching pattern:', matchingPattern);
context.setVariable("searchKey", matchingPattern);
