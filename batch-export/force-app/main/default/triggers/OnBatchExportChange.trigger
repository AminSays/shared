/**
 * @name: OnBatchExportChange
 * @description: This trigger is invoked after insert and update operations on the Batch_Export__c object.
 *  It calls the ExportUtility.scheduleCheck method to schedule an async job for processing the export.
 */
trigger OnBatchExportChange on Batch_Export__c (after insert, after update) {
    for (Batch_Export__c batchExport : Trigger.new ) {
        ExportUtility.runAgain(batchExport); // run for one/first record only
        break;
    }
}