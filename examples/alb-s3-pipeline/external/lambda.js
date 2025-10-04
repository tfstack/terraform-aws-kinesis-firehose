const { FirehoseClient, PutRecordCommand } = require('@aws-sdk/client-firehose');

const firehose = new FirehoseClient();

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));

    // Parse the request from ALB event
    const path = event.path || '/';
    const method = event.httpMethod || 'GET';
    const headers = event.headers || {};

    console.log('Path:', path);
    console.log('Method:', method);

    // Extract real source IP from headers (ALB provides this)
    const sourceIp = headers['x-forwarded-for'] ||
                    headers['x-real-ip'] ||
                    event.requestContext?.identity?.sourceIp ||
                    'unknown';

    // Extract real request ID from ALB context
    const requestId = event.requestContext?.requestId ||
                     headers['x-amzn-trace-id'] ||
                     'unknown';

    // Create log entry for WAF logging
    const logEntry = {
        timestamp: new Date().toISOString(),
        requestId: requestId,
        method: method,
        path: path,
        userAgent: headers['user-agent'] || 'unknown',
        sourceIp: sourceIp,
        headers: headers,
        queryString: event.queryStringParameters || {},
        body: event.body || null,
        // Add WAF-specific information
        wafAction: 'ALLOW', // This would be 'BLOCK' if WAF blocked the request
        responseCode: 200 // This would be the actual response code
    };

    // This will be called after we determine the response
    const sendLogToFirehose = async (logEntry) => {
        try {
            await firehose.send(new PutRecordCommand({
                DeliveryStreamName: process.env.FIREHOSE_STREAM_NAME,
                Record: {
                    Data: Buffer.from(JSON.stringify(logEntry) + '\n')
                }
            }));
            console.log('Log sent to Firehose successfully');
        } catch (error) {
            console.error('Error sending log to Firehose:', error);
        }
    };

    // Default response headers
    const responseHeaders = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS'
    };

    // Handle different paths
    if (path === '/health') {
        console.log('Handling /health endpoint');
        const response = {
            statusCode: 200,
            headers: responseHeaders,
            body: JSON.stringify({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                environment: process.env.ENVIRONMENT || 'dev'
            })
        };

        // Update log entry with actual response code
        logEntry.responseCode = response.statusCode;

        // Send log to Firehose
        await sendLogToFirehose(logEntry);

        return response;
    }

    if (path === '/api/hello') {
        console.log('Handling /api/hello endpoint');
        const response = {
            statusCode: 200,
            headers: responseHeaders,
            body: JSON.stringify({
                message: 'Hello from Lambda!',
                timestamp: new Date().toISOString(),
                method: method,
                path: path
            })
        };

        // Update log entry with actual response code
        logEntry.responseCode = response.statusCode;

        // Send log to Firehose
        await sendLogToFirehose(logEntry);

        return response;
    }

    if (path === '/api/info') {
        console.log('Handling /api/info endpoint');
        const response = {
            statusCode: 200,
            headers: responseHeaders,
            body: JSON.stringify({
                service: 'Lambda ALB Example',
                version: '1.0.0',
                environment: process.env.ENVIRONMENT || 'dev',
                region: process.env.AWS_REGION,
                timestamp: new Date().toISOString()
            })
        };

        // Update log entry with actual response code
        logEntry.responseCode = response.statusCode;

        // Send log to Firehose
        await sendLogToFirehose(logEntry);

        return response;
    }

    // Default response for root path
    if (path === '/') {
        console.log('Handling root path /');
        const response = {
            statusCode: 200,
            headers: responseHeaders,
            body: JSON.stringify({
                message: 'Welcome to Lambda ALB Example',
                endpoints: [
                    '/health - Health check endpoint',
                    '/api/hello - Hello endpoint',
                    '/api/info - Service information'
                ],
                timestamp: new Date().toISOString()
            })
        };

        // Update log entry with actual response code
        logEntry.responseCode = response.statusCode;

        // Send log to Firehose
        await sendLogToFirehose(logEntry);

        return response;
    }

    // 404 for unknown paths
    console.log('Handling unknown path:', path);
    const response = {
        statusCode: 404,
        headers: responseHeaders,
        body: JSON.stringify({
            error: 'Not Found',
            message: `Path ${path} not found`,
            timestamp: new Date().toISOString()
        })
    };

    // Update log entry with actual response code
    logEntry.responseCode = response.statusCode;

    return response;
};
