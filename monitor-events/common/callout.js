const https = require('https');
const Org = require('../common/orgAccess');
const AppError = require('../common/appError');
const Utility = require('./utility');
class Callout {
    //static allowedMethod = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
    static allowedMethod = ['GET', 'POST'];
    static access_token = '';
    static async authorize() {
        try {
            var reqData = 'grant_type=password' +
                '&client_id=' + process.env.CLIENT_ID +
                '&client_secret=' + process.env.CLIENT_SECRET +
                '&username=' + process.env.USERNAME +
                '&password=Simple#1234';
            const rslt = await this.call(process.env.LOGIN_PATH, 'POST', reqData, 'BODY', true);
            return rslt.access_token;
        }
        catch (err) {
            throw new AppError(err, 'Failed to Authorize.');
        }
    }
    static async call(relUrl, type = 'GET', body = '', bodyType = 'JSON', authCall = false) {
        try {
            var options = '';
            var method = '';
            var reqData = '';
            var contentType = '';
            var contentLength = 0;
            var url = '';
            //validate type
            method = this.allowedMethod.find(element => element == type.toUpperCase());
            if (method == undefined || method == '') {
                throw new Error('Invalid Type: ' + type);
            }
            //validate url
            if (relUrl == undefined || relUrl == '') {
                throw new Error('Invalid URL: ' + relUrl);
            }
            url = process.env.ORG_URL + relUrl;
            //validate body
            if (typeof body === 'object' && !Array.isArray(body) && body != null && body != undefined) {
                reqData = JSON.stringify(body);
            }
            else {
                reqData = body;
            }

            contentLength = Buffer.byteLength(reqData);

            //validate bodyType
            if (bodyType == 'JSON') {
                contentType = 'application/json';
            }
            else if (bodyType == 'BODY') {
                contentType = 'application/x-www-form-urlencoded';
            }
            else {
                throw new Error('Invalid Content Type: ' + contentType);
            }

            if (authCall) {
                options = {
                    method: method,
                    headers: {
                        'Content-Type': contentType,
                        'Content-Length': contentLength,
                    },
                    timeout: 1000, // in ms
                };
            }
            else {
                //validate Authorization
                if (this.access_token == '') {
                    this.access_token = await this.authorize();
                }
                options = {
                    method: method,
                    headers: {
                        'Content-Type': contentType,
                        'Content-Length': contentLength,
                        'Authorization': 'OAuth ' + this.access_token
                    },
                    timeout: 1000, // in ms
                };
            }

            const thisRef = this;

            return new Promise((resolve, reject) => {
                const req = https.request(url, options, (res) => {
                    if (res.statusCode < 200 || res.statusCode > 299) {
                        return reject(new Error(`HTTP status code ${res.statusCode}`))
                    }
                    const body = [];
                    res.on('data', (chunk) => body.push(chunk));
                    res.on('end', () => {
                        const resString = Buffer.concat(body).toString();
                        if(thisRef.isJson(resString)) {
                            resolve(JSON.parse(resString));
                        }
                        else {
                            resolve(resString);
                        }
                    });
                });

                req.on('error', (err) => {
                    reject(err)
                });

                req.on('timeout', () => {
                    req.destroy()
                    reject(new Error('Request time out'))
                });
                if (reqData != null && reqData != undefined && reqData != '') {
                    req.write(reqData);
                }
                req.end();
            });
        }
        catch (err) {
            throw new AppError(err, 'Callout failed.');
        }
    }
     static isJson(str) {
        try {
            JSON.parse(str);
        } catch (e) {
            return false;
        }
        return true;
    }
}
module.exports = Callout;