/*
 * @name: BulkAPIUtility
 * @description: This class provides utility methods for interacting with the Salesforce Bulk API.
 * @depdendecy: Named Credentials, here are the steps:
 * 1. Create Connected App: Enable OAuth, Client Cred, Specify Client Cred User. Take Client ID and Secret
 * 2. Create Exernal Credential, OAuth2.0, Client Cred, mydomain URL
 * 3. In Ex Cred, Add Custom Header, grant_type=client_credentials, content-type=application/json
 * 4. In Ex Cred, Add Pricipals, Client ID, Secret
 * 5. Create Named Cred for Ex Cred, Enable Generate Auth Header
 * 6. Add permission in Profile > External Credential Principal Access
 */


public with sharing class BulkAPIUtility {
    private static final String NAMED_CRED = 'pdo_org'; ///services/data/v62.0/
    private static final Boolean DEBUG = false;

    public String jobId {get; private set;}
    public String state {get; private set;}
    public String query {get; private set;}
    public Integer recordsProcessed {get; private set;}
    public String error  {get; private set;}
    public Integer maxRecords {get; private set;}
    public String recordLocator {get; private set;}
    public Integer currentPageSize {get; private set;}

    /*
    @name: hasError
    @description: public method to check if there is error in process
    @return: Has Error: True/False
    */
    public boolean hasError {
        get { 
            if(this.error == ''){
                return false;
            }
            else {
                return true;
            }
        }
    }
    /*
    @name: BulkAPIUtility
    @description: public constructor to set initial values
    */
    public BulkAPIUtility(){
        this.jobId = '';
        this.state = 'NotStarted';
        this.query = '';
        this.recordsProcessed = 0;
        this.error = '';
        this.recordLocator = '';
        this.maxRecords = 0;
    }
    /*
    @name: BulkAPIUtility
    @description: public constructor to set initial values
    @param: string bulkJobId - Bulk API Job Id
    */
    public BulkAPIUtility(string bulkJobId){
        this.jobId = bulkJobId;
        this.state = 'Submitted';
        this.query = '';
        this.recordsProcessed = 0;
        this.error = '';
        this.recordLocator = '';
        this.maxRecords = 0;
    }
    /*
    @name: fireAPI
    @description: private method to for API callout
    @param: string type - GET or POST
    @param: string relUrl - the relative url of the API endpoint
    @param: string body - the payload in JSON format
    @return: HttpResponse - the response from the API call
    */
    private HttpResponse fireAPI(string type, string relUrl, string body){
        //check type
        if(type != 'GET' && type != 'POST') {
            handleError('Invalid type. Accepted: GET, POST');
            return null;
        }
        try {
                string endPoint = 'callout:' + NAMED_CRED + relUrl;

                if(DEBUG) {
                    debugLog('Endpoint: ' + endPoint);
                    debugLog('Type: ' + type);
                }

                HttpRequest request = new HttpRequest();
                request.setMethod(type);
                request.setEndpoint(endPoint);
                if(body != null) {
                    request.setBody(body);
                }

                HttpResponse response = (new Http()).send(request);
                if(DEBUG) {
                    debugLog('Response: ' + response);
                }
                return response;
        }
        Catch(Exception ex) {
            handleException(ex);
            return null;
        }
    }
    /*
    @name: parseRespose
    @description: private method to parse HTTP repose and get values
    @param: HttpResponse response - response from API call
    @return: Map<String, Object> - map of key and values found in response
    */
    private Map<String, Object> parseRespose(HttpResponse response) {
        try {
            if(response.getStatusCode() == 200) {
                JSONParser parser = JSON.createParser(response.getBody());
                Map<string, string> jsonMap = new Map<string,string>();
                while (parser.nextToken() != null) {
                    if (parser.getCurrentToken() == JSONToken.FIELD_NAME) {
                        string key = parser.getText();
                        parser.nextToken();
                        string value = parser.getText();
                        jsonMap.put(key, value);
                    }
                }
                return jsonMap;
            }
            return null;
        }
        Catch(Exception ex) {
            handleException(ex);
            return null;
        }
    }
    /*
    @name: checkError
    @description: private method to check if there is error in Http response and error details in log
    @param: HttpResponse response - response from API call
    */
    private void checkError(HttpResponse response){
        try {
            if(response != null && response.getStatusCode() != 200) {
                JSONParser parser = JSON.createParser(response.getBody());
                Map<string, string> jsonMap = new Map<string,string>();
                while (parser.nextToken() != null) {
                    if (parser.getCurrentToken() == JSONToken.FIELD_NAME) {
                        string key = parser.getText();
                        parser.nextToken();
                        string value = parser.getText();
                        jsonMap.put(key, value);
                    }
                }
                handleError(jsonMap.get('errorCode').toString() + ' : ' + jsonMap.get('message').toString());
            }
        }
        Catch(Exception ex) {
            handleException(ex);
        }
    }
    /*
    @name: checkError
    @description: private method to put message in debug log
    @param: String message - message for debug log
    */
    private void debugLog(String message){
        System.debug(LoggingLevel.DEBUG, message); // NOPMD
    }
    /*
    @name: handleError
    @description: private method to put error message in debug log
    @param: String message - Error Message for debug log
    */
    private void handleError(String errorMessage) {
        this.error = errorMessage;
        this.state = 'Error';
        System.debug(LoggingLevel.ERROR, this.error); // NOPMD
    }
    /*
    @name: handleException
    @description: private method to handle exceptions
    @param: Exception ex -  exception to be handeled
    */
    private void handleException(Exception ex) {
        handleError(ex.getTypeName() + ' : ' + ex.getMessage() + ' at ' + ex.getLineNumber());
        System.debug(LoggingLevel.ERROR, ex); // NOPMD
    }
    /*
    @name: submitQuery
    @description: public method to submit Bulk API Export query job
    @param: String exportQuery - query to be used for export
    */
    public void submitQuery(String exportQuery) {
        this.query = exportQuery;

        if(this.query == null || this.query == '') {
            handleError('Query not specified.');
            return;
        }
        try {
            string relUrl = '/jobs/query';

            String body = '{ '+
                            '"operation": "query",' +  
                            '"lineEnding": "LF",' +                            
                            '"query": "'+ this.query + '"' +
                        '}';

            HttpResponse response = fireAPI('POST', relUrl, body);
            checkError(response);
            if(this.hasError == false) {
                Map<string, Object> jsonMap = parseRespose(response);
                if(jsonMap != null) {
                    this.jobId = jsonMap.get('id').toString();
                    this.state = 'Submitted';
                }
                else {
                    handleError('Unable to parse response from submitQuery.');
                }
            }
        }
       Catch(Exception ex) {
            handleException(ex);
        }
    }
   /*
    @name: checkStatus
    @description: public method to check status of Bulk API Export query job
    @param: String bulkJobId - Job Id from Bulk API Export query job
    */
    public void checkStatus(String bulkJobId) {
        this.jobId = bulkJobId;

        if(this.jobId == null || this.jobId == ''){
            handleError('JobId not specified.');
            return;
        }
        try {
            string relUrl = '/jobs/query/' + this.jobId;

            HttpResponse response = fireAPI('GET', relUrl, '');
            checkError(response);
            if(this.hasError == false) {
                Map<string, Object> jsonMap = parseRespose(response);
                if(jsonMap != null) {
                    this.state = jsonMap.get('state').toString();
                    this.recordsProcessed = Integer.valueOf(jsonMap.get('numberRecordsProcessed'));
                }
                else {
                    handleError('Unable to parse response from checkStatus.');
                }
            }
        }
       Catch(Exception ex) {
            handleException(ex);
        }
    }
    /*
    @name: getResult
    @description: public method to get result from Bulk API Export query job
    @param: String bulkJobId - Job Id from Bulk API Export query job
    @param: Integer pageSize - size of page
    @param: String recLocator - record locatore for page
    @return: String response from Bulk API Export query job
    */
    public String getResult(String bulkJobId, Integer pageSize, String recLocator) {
        this.jobId = bulkJobId;
        this.maxRecords = pageSize;
        this.recordLocator = recLocator;

        if(this.jobId == null || this.jobId == ''){
            handleError('JobId not specified.');
            return '';
        }

        if(this.maxRecords == 0) {
            handleError('Max Records not specified.');
            return '';
        }
        try {
            string relUrl = '/jobs/query/' + this.jobId +  '/results?maxRecords=' + this.maxRecords;
            if(this.recordLocator != '' && this.recordLocator != null) {
                relUrl = relUrl + '&locator=' + this.recordLocator;
            }

            HttpResponse response = fireAPI('GET', relUrl, '');
            checkError(response);

            if(this.hasError == false){
                this.currentPageSize = Integer.valueOf(response.getHeader('Sforce-NumberOfRecords'));
                this.recordLocator = response.getHeader('Sforce-Locator');

                if(this.recordLocator == null || this.recordLocator == ''){
                    this.recordLocator = '';
                }
                return response.getBody();
            }
            else {
                return '';
            }
        }
        Catch(Exception ex) {
            handleException(ex);
            return null;
        }
    }
}