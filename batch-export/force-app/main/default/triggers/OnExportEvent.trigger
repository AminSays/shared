/*
 * @name: OnExportEvent
 * @description: This trigger is invoked after insert on the Platform Event Export__e.
 *  It calls the ExportUtility.exportData method to export current page of data
    @dependency: OnExportEventTriggerConfig to access Named Credentials
*/
trigger OnExportEvent on Export__e (after insert) {
    for (Export__e exportEvent : Trigger.New) {
        if(exportEvent.Record_Locator__c == 'first'){
            ExportUtility.exportData(exportEvent.Batch_Export_Id__c, '');
        }
        else {
            ExportUtility.exportData(exportEvent.Batch_Export_Id__c, exportEvent.Record_Locator__c);
        }
    }
}