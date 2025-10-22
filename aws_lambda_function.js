// AWS Lambda function for Alexa Smart Home Skill
// This runs in the cloud and handles all Alexa requests

const https = require('https');

// Your app's API endpoints (replace with your actual URLs)
const APP_BASE_URL = 'https://your-app-api.com'; // Replace with your app's API URL
const OAUTH_TOKEN_ENDPOINT = `${APP_BASE_URL}/oauth/token`;
const ALEXA_HANDLER_ENDPOINT = `${APP_BASE_URL}/alexa/handle`;

// Main Lambda handler
exports.handler = async (event) => {
    console.log('Received Alexa event:', JSON.stringify(event, null, 2));
    
    try {
        const directive = event.directive;
        const namespace = directive.header.namespace;
        const name = directive.header.name;
        
        // Handle different types of requests
        switch (namespace) {
            case 'Alexa.Authorization':
                return handleAuthorization(directive);
                
            case 'Alexa.Discovery':
                return await handleDiscovery(directive);
                
            case 'Alexa.PowerController':
                return await handlePowerControl(directive);
                
            case 'Alexa':
                if (name === 'ReportState') {
                    return await handleStateReport(directive);
                }
                break;
                
            default:
                return buildErrorResponse('INVALID_DIRECTIVE', `Unsupported namespace: ${namespace}`);
        }
        
        return buildErrorResponse('INVALID_DIRECTIVE', `Unsupported directive: ${namespace}.${name}`);
        
    } catch (error) {
        console.error('Lambda error:', error);
        return buildErrorResponse('INTERNAL_ERROR', error.message);
    }
};

// Handle account linking authorization
function handleAuthorization(directive) {
    const grantCode = directive.payload.grant.code;
    
    if (!grantCode) {
        return buildErrorResponse('INVALID_AUTHORIZATION_CREDENTIAL', 'Missing grant code');
    }
    
    // For authorization, we just acknowledge receipt
    // The actual token exchange happens during device discovery
    return {
        event: {
            header: {
                namespace: 'Alexa.Authorization',
                name: 'AcceptGrant.Response',
                payloadVersion: '3',
                messageId: generateMessageId()
            },
            payload: {}
        }
    };
}

// Handle device discovery requests
async function handleDiscovery(directive) {
    try {
        const accessToken = directive.payload.scope.token;
        
        if (!accessToken) {
            return buildErrorResponse('INVALID_AUTHORIZATION_CREDENTIAL', 'Missing access token');
        }
        
        // Forward to your app's Alexa handler
        const response = await callAppAPI('POST', '/alexa/handle', {
            directive: directive
        }, accessToken);
        
        return response;
        
    } catch (error) {
        console.error('Discovery error:', error);
        return buildErrorResponse('INTERNAL_ERROR', `Discovery failed: ${error.message}`);
    }
}

// Handle power control commands (TurnOn, TurnOff)
async function handlePowerControl(directive) {
    try {
        const accessToken = directive.endpoint.scope.token;
        
        if (!accessToken) {
            return buildErrorResponse('INVALID_AUTHORIZATION_CREDENTIAL', 'Missing access token');
        }
        
        // Forward to your app's Alexa handler
        const response = await callAppAPI('POST', '/alexa/handle', {
            directive: directive
        }, accessToken);
        
        return response;
        
    } catch (error) {
        console.error('Power control error:', error);
        return buildErrorResponse('INTERNAL_ERROR', `Power control failed: ${error.message}`);
    }
}

// Handle state report requests
async function handleStateReport(directive) {
    try {
        const accessToken = directive.endpoint.scope.token;
        
        if (!accessToken) {
            return buildErrorResponse('INVALID_AUTHORIZATION_CREDENTIAL', 'Missing access token');
        }
        
        // Forward to your app's Alexa handler
        const response = await callAppAPI('POST', '/alexa/handle', {
            directive: directive
        }, accessToken);
        
        return response;
        
    } catch (error) {
        console.error('State report error:', error);
        return buildErrorResponse('INTERNAL_ERROR', `State report failed: ${error.message}`);
    }
}

// Helper function to call your app's API
function callAppAPI(method, path, data, accessToken) {
    return new Promise((resolve, reject) => {
        const url = new URL(APP_BASE_URL + path);
        
        const postData = JSON.stringify(data);
        
        const options = {
            hostname: url.hostname,
            port: url.port || (url.protocol === 'https:' ? 443 : 80),
            path: url.pathname + url.search,
            method: method,
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData),
                'Authorization': `Bearer ${accessToken}`
            }
        };
        
        const req = https.request(options, (res) => {
            let responseData = '';
            
            res.on('data', (chunk) => {
                responseData += chunk;
            });
            
            res.on('end', () => {
                try {
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                        const response = JSON.parse(responseData);
                        resolve(response);
                    } else {
                        reject(new Error(`HTTP ${res.statusCode}: ${responseData}`));
                    }
                } catch (parseError) {
                    reject(new Error(`Failed to parse response: ${parseError.message}`));
                }
            });
        });
        
        req.on('error', (error) => {
            reject(error);
        });
        
        req.write(postData);
        req.end();
    });
}

// Helper function to build error responses
function buildErrorResponse(errorType, errorMessage) {
    return {
        event: {
            header: {
                namespace: 'Alexa',
                name: 'ErrorResponse',
                payloadVersion: '3',
                messageId: generateMessageId()
            },
            payload: {
                type: errorType,
                message: errorMessage
            }
        }
    };
}

// Helper function to generate unique message IDs
function generateMessageId() {
    return `msg_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
}

// Export for testing
module.exports = {
    handler: exports.handler,
    handleAuthorization,
    handleDiscovery,
    handlePowerControl,
    handleStateReport,
    callAppAPI,
    buildErrorResponse,
    generateMessageId
};