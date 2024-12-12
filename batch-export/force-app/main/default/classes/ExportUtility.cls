/*
@name: ExportUtility
@description: Utility class to export data from Bulk API
Depedency: Dataweaver script, following are th steps to deploy from Command CLI, VSCOde Deploy might not work
sf project convert source --source-dir ./mdapi
sf project deploy start --source-dir ./mdapi
*/
public class ExportUtility implements Queueable, Database.AllowsCallouts {
    private Id exportId;
    private static final Integer CHECKDELAYMIN = 1;
    private static final Boolean DEBUG = true;
    private static final String REPORTNAME = 'Cases with Batch Export Report';

    private Batch_Export__c batchExport;
    private BulkAPIUtility bulkAPI;

    List<string> header = new List<string>();

    /*
    @name: ExportUtility
    @description: public constructor to initialize Export Utility
    @param: String batchExportId - Id of Batch Export record under processing
    */
    public ExportUtility(String batchExportId){
        exportId = batchExportId;
        batchExport = [SELECT Id, Name, Job_Id__c, Page_Size__c, Target_Object__c, Query__c, Filter_Criteria__c, Bulk_API_Status__c, Export_Status__c, Log__c, Records_Processed__c, Records_Exported__c, Records_Fetched__c, Has_Error__c FROM Batch_Export__c WHERE Id = :this.exportId];
    }
    /*
    @name: runAgain
    @description: public static method to run Export as per current status
    @param: Batch_Export__c newExport - Batch Export record under processing
    @return: Id - Job Id of enqueued job
    */
    public static Id runAgain(Batch_Export__c newExport) {
        switch on newExport.Export_Status__c { //export is Enqueued, run immediately
            when 'Enqueued' {
                return System.enqueueJob(new ExportUtility(newExport.Id), 0);    
            }
            when 'Submitted' { //export submitted to bulk api, check status after delay
                return System.enqueueJob(new ExportUtility(newExport.Id), CHECKDELAYMIN);
            }
            when 'Processing' { //export submitted to bulk api, check status after delay
                return System.enqueueJob(new ExportUtility(newExport.Id), CHECKDELAYMIN);
            }
            /* Exporting through event not as quable process
            when 'Exporting' { //export is processing data, run again immediately
                (new ExportUtility(newExport.Id)).execute(null);
                return null;
            }*/
            when else { //process already complete, no action needed
                return null;
            }
        }
    }
    /*
    @name: execute
    @description: public static execute method to run as queuable process
    @param: QueueableContext context - Queuable context
    */
    public void execute(QueueableContext context) {
        switch on batchExport.Export_Status__c { //export is Enqueued, run immediately
            when 'Enqueued' {
                submitJob();   
            }
            when 'Submitted' { //export submitted to bulk api, check status after delay
                checkStatus();
            }
            when 'Processing' { //export submitted to bulk api, check status after delay
                checkStatus();
            }
            /* Exporting through event not as quable process
            when 'Exporting' { //export is processing data, run again immediately
                exportData();   
            }*/
            when else { //process already complete, no action needed
                return;
            }
        }
    }
    /*
    @name: submitJob
    @description: private method to submit Bulk API Query Job
    */
    private void submitJob() {
        batchExport.Start_Time__c = Datetime.now();
        batchExport.End_Time__c = null;
        batchExport.Log__c = '';
        batchExport.Records_Processed__c = 0;
        batchExport.Records_Fetched__c = 0;
        batchExport.Records_Exported__c = 0;

        addLog('Submitting Bulk API Job.');

        bulkAPI = new BulkAPIUtility();
        bulkAPI.submitQuery(batchExport.Query__c);

        if(bulkAPI.state == 'Submitted' && bulkAPI.hasError == false) {
            batchExport.Job_Id__c = bulkAPI.jobId;
            batchExport.Bulk_API_Status__c = bulkAPI.state;
            batchExport.Export_Status__c = 'Submitted';
            addLog('Bulk API Job Submitted.');            
        }
        else {
            addLog('Bulk API Job Failed.');
            addLog(bulkAPI.error);
            handleError();
        }
        Database.update(batchExport);
    }
    /*
    @name: checkStatus
    @description: private method to check status of Bulk API Query Job
    */
    private void checkStatus() {
        addLog('Checking Bulk API Status.');

        bulkAPI = new BulkAPIUtility();
        bulkAPI.checkStatus(batchExport.Job_Id__c);

        batchExport.Bulk_API_Status__c = bulkAPI.state;
        batchExport.Records_Processed__c = bulkAPI.recordsProcessed;

        if(bulkAPI.state == 'Submitted' && bulkAPI.hasError == false) {
            addLog('Bulk API Still in submitted state.');
        }
        else if(bulkAPI.state == 'InProgress' && bulkAPI.hasError == false) {
            batchExport.Export_Status__c = 'Processing';
            addLog('Bulk API is in progress.');
        }
        else if(bulkAPI.state == 'JobComplete' && bulkAPI.hasError == false) {
            addLog('Bulk API is now complete.');
            batchExport.Records_Processed__c = bulkAPI.recordsProcessed;
            batchExport.Export_Status__c = 'Exporting';
            batchExport.Records_Exported__c = 0;
            publishExportEvent('first');
            //exportData();//starting export
        }
        else {
            addLog('Bulk API Job Failed.');
            addLog(bulkAPI.error);
            handleError();
        }
        Database.update(batchExport);
    }
    /*
    @name: publishExportEvent
    @description: public method to publish event for export with record locator to be exported
    @param: String recordLocator - record locator for the page to be exported
    */
    public void publishExportEvent(String recordLocator) {
        try {
            addLog('Publishing export event for: ' + recordLocator);
            Export__e exportEvent = new Export__e();
            exportEvent.Batch_Export_Id__c = this.batchExport.Id;
            exportEvent.Record_Locator__c = recordLocator;
            Database.SaveResult result = EventBus.publish(exportEvent);
            if(result.isSuccess()){
                addLog('Export Event published for: ' + recordLocator);
            }
            else {
                for(Database.Error error : result.getErrors()) {
                    addLog(error.getStatusCode() + ' : ' + error.getMessage());
                }
                handleError();
            }
        }
        Catch(Exception ex){
            handleException(ex);
        }
    }
    /*
    @name: exportData
    @description: public static callout method to export data from Bulk API to
    @param: String batchExportId - Id of Batch Export record
    @param: String recordLocator - record locator for the page to be exported
    */
    @future (callout=true)
    public static void exportData(String batchExportId, String recordLocator){
        ExportUtility exportUtil = new ExportUtility(batchExportId);
        exportUtil.exportData(recordLocator);
    }
    private void exportData(string recordLocator) {
        addLog('Exporting page for record locator: ' + recordLocator);
        bulkAPI = new BulkAPIUtility();

        string csvData = bulkAPI.getResult(batchExport.Job_Id__c, (Integer) batchExport.Page_Size__c, recordLocator);
        
        if(bulkAPI.hasError == false) {
            addLog('Records exported: ' + bulkAPI.currentPageSize);

            if(batchExport.Target_Object__c.toUpperCase() == 'FILE') {
                exportToFile(csvData);
            }
            else {
                insertToObjectDW(csvData);
            }

            //System.debug('locator: ' + bulkAPI.recordLocator);
            //System.debug('locator: ' + String.isBlank(bulkAPI.recordLocator));

            if(batchExport.Has_Error__c == false) {
                batchExport.Records_Fetched__c = batchExport.Records_Fetched__c + bulkAPI.currentPageSize;

                if(String.isBlank(bulkAPI.recordLocator) || bulkAPI.recordLocator == 'null') {
                    addLog('No more pages to export.');
                    this.exportReport();//export data from Report
                    batchExport.Export_Status__c = 'Completed';
                    batchExport.End_Time__c = Datetime.now();
                }
                else {
                    this.publishExportEvent(bulkAPI.recordLocator);
                }
            }
            else {
                addLog('Insert Failed.');
                handleError();
            }
        }
        else {
            addLog('Export Failed.');
            addLog(bulkAPI.error);
            handleError();
        }
        
        Database.update(batchExport);
    }
    /*
    @name: insertToObjectDW
    @description: private method to insert Bulk API response (CSV data) to Custom object using Dataweave
    @param: String csvData - CSV Data to be parsed and inserted to custom object
    */
    private void insertToObjectDW(String csvData){
        try{
            addLog('Inserting data to object: ' + batchExport.Target_Object__c) ;

            DataWeave.Script dwscript;
            //add Dataweave script here for other target objects
            switch on batchExport.Target_Object__c.toUpperCase() {
                when 'CASE__C' {
                    dwscript = new DataWeaveScriptResource.csvToCase_c();                    
                }
                when else {
                    addLog('Dataweave not defined for the target object: ' + batchExport.Target_Object__c) ;
                    handleError();
                    return;    
                }
            }

            if(dwscript != null){
                DataWeave.Result dwresult = dwscript.execute(new Map<String, Object>{'records' => csvData});
                List<SObject> lstRecords = (List<SObject>) dwresult.getValue();
                //map exported records with Batch export record
                for(SObject aRecord : lstRecords) {
                    aRecord.put('Batch_Export__c', this.batchExport.Id);
                }

                Database.insert(lstRecords);
                
                addLog('Inserted data to object: ' + lstRecords.size());
                batchExport.Records_Exported__c = batchExport.Records_Exported__c + lstRecords.size();
            }
        }
        Catch(Exception ex){
            handleException(ex);
        }
    }
    /*
    @name: exportReport
    @description: public method to export Report as excel file
    */
    public void exportReport() {

        List<Report> reportList = [SELECT Id, DeveloperName FROM Report WHERE Name = :REPORTNAME];
        if(reportList.size() == 0){
            addLog('Report not found.');
            handleError();
            return;
        }
        try{
            Report theReport = reportList.get(0);

            // Get the report metadata
            Reports.ReportDescribeResult describe = Reports.ReportManager.describeReport(theReport.Id);
            Reports.ReportMetadata reportMd = describe.getReportMetadata();

            //find filter
            Reports.ReportFilter theFilter;

            for(Reports.ReportFilter reportFilter : reportMd.getReportFilters()) {
                if(reportFilter.getColumn().contains('Job_Id__c')){
                    thefilter = reportFilter;
                }
            }

            if(theFilter == null){
                addLog('Report Filter not found.');
                handleError();
                return;
            }
            //set filter value   
            theFilter.setValue(this.batchExport.Job_Id__c);

            //Report exporting to excel
            String instanceName = System.URL.getOrgDomainUrl().toExternalForm();
            String url = instanceName + '/servlet/PrintableViewDownloadServlet?isdtp=p1&reportId=' + theReport.Id + '&csv=1&enc=utf-8';

            ApexPages.PageReference objPage = new ApexPages.PageReference(url);
            Blob content = objPage.getContent();

            string fileName = REPORTNAME + '.xlsx';

            //Create File
            addLog('Creating File: ' + fileName);

            ContentVersion contentVersion = new ContentVersion();
            contentVersion.ContentLocation = 'S'; // S = Stored in Salesforce
            contentVersion.PathOnClient = fileName;
            contentVersion.Title = fileName;
            contentVersion.VersionData = content;
            insert(contentVersion);

            string contentDocumentId = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;

            //Link File to Record
            addLog('File created: ' + contentDocumentId);

            ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
            contentDocumentLink.ContentDocumentId = contentDocumentId;
            contentDocumentLink.LinkedEntityId = batchExport.Id;
            contentDocumentLink.ShareType = 'I'; // Inferred permission
            contentDocumentLink.Visibility = 'InternalUsers';
            insert(contentDocumentLink);
            addLog('Link created: ' + contentDocumentLink.Id);
            batchExport.Records_Exported__c = batchExport.Records_Exported__c + bulkAPI.currentPageSize;

        }
        Catch(Exception ex){
            handleException(ex);
        }
    }
    /*
    @name: exportToFile
    @description: private method to export Bulk API response (CSV data) to file
    @param: String csvData - CSV Data to be parsed and exported to file
    */
    private void exportToFile(String csvData){
        try {
            integer fileCount = Integer.valueOf(batchExport.Records_Exported__c/batchExport.Page_Size__c + 1);
            string fileName = 'Export_' + fileCount.toString() + '.csv';
            addLog('Creating File: ' + fileName);

            ContentVersion contentVersion = new ContentVersion();
            contentVersion.ContentLocation = 'S'; // S = Stored in Salesforce
            contentVersion.PathOnClient = fileName;
            contentVersion.Title = fileName;
            contentVersion.VersionData = Blob.valueOf(csvData);
            insert(contentVersion);

            string contentDocumentId = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;

            addLog('File created: ' + contentDocumentId);

            ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
            contentDocumentLink.ContentDocumentId = contentDocumentId;
            contentDocumentLink.LinkedEntityId = batchExport.Id;
            contentDocumentLink.ShareType = 'I'; // Inferred permission
            contentDocumentLink.Visibility = 'InternalUsers';
            insert(contentDocumentLink);
            addLog('Link created: ' + contentDocumentLink.Id);
            batchExport.Records_Exported__c = batchExport.Records_Exported__c + bulkAPI.currentPageSize;
        }
        Catch(Exception ex){
            handleException(ex);
        }
    }
    /*
    @name: addLog
    @description: private method to add message to Log
    @param: String message - message to be logged
    */
    private void addLog(String message) {
        if(DEBUG) {
            System.debug(LoggingLevel.DEBUG, message);
        }
        batchExport.Log__c = batchExport.Log__c + '\n' + DateTime.now() + ' : ' + message;
    }
    /*
    @name: handleError
    @description: private method to handle error in process
    */
    private void handleError() {
        batchExport.End_Time__c = Datetime.now();
        batchExport.Has_Error__c = true;
        batchExport.Export_Status__c = 'Completed';
    }
    /*
    @name: handleException
    @description: private method to handle exception in process
    @param: Exception ex - exception to be handled
    */
    private void handleException(Exception ex) {
        batchExport.Has_Error__c = true;
        addLog(ex.getTypeName() + ' : ' + ex.getMessage() + ' at ' + ex.getLineNumber());
    }
}