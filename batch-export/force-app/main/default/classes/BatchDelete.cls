/**
* @name: BatchDelete
* @description: This class implements the Database.Batchable interface for Salesforce, allowing it to run a batch job on a specified object. 
* It constructs a SOQL query to retrieve records based on a given condition and deletes them in batches. After deletion, it empties the recycle bin to ensure complete data removal. This class provides error handling for potential issues during the deletion process.
*/
public with sharing class BatchDelete implements Database.Batchable<sObject>, Database.Stateful {
    String query;
    Integer totalRecs = 0;
    /**
    * @name: BatchDelete
    * @description: Constructor for the BatchDelete class. Takes an object name as a parameter and constructs a SOQL query to retrieve records for deletion.
    * @param objectName: The name of the object (SObject) on which the batch deletion will be performed.
    * @return: void
    */
    public BatchDelete(String objectName) {
        query = 'SELECT Id FROM ' + objectName;
    }
    /**
    * @name: start
    * @description: Start method for the batch job. Returns a Database.QueryLocator object with the constructed SOQL query.
    * @param BC: The Database.BatchableContext object for the batch job.
    * @return: Database.QueryLocator
    */
    public Database.QueryLocator start(Database.BatchableContext BC) {
        System.debug(query);
        return Database.getQueryLocator(query);
    }
    /**
    * @name: execute
    * @description: Main execution method for the batch job. Deletes the records retrieved in the current batch and empties the recycle bin.
    * @param BC: The Database.BatchableContext object for the batch job.
    * @param scope: List of sObjects to be deleted in the current batch.
    * @return: void
    */
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        totalRecs += scope.size();
        Database.delete(scope, false); // Use "false" to allow partial success
        Database.emptyRecycleBin(scope); // Empty the recycle bin to ensure complete data removal
    }
    /**
    * @name: finish
    * @description: Finish method for the batch job. Logs the total number of records deleted.
    * @param BC: The Database.BatchableContext object for the batch job.
    * @return: void
    */
    public void finish(Database.BatchableContext BC) {
        System.debug('Records deleted: ' + totalRecs);
    }
    /**
    * @name: execute
    * @description: Additional execution method for the batch job. Logs the error message in case of a DMLException during record deletion.
    * @param BC: The Database.BatchableContext object for the batch job.
    * @param scope: List of sObjects to be deleted in the current batch.
    * @return: void
    */
    public void execute(Database.BatchableContext BC, SObject scope) {
        try {
            execute(BC, new List<sObject>{scope});
        } catch (DMLException e) {
            error(e.getMessage());
        }
    }
    /**
    * @name: error
    * @description: Error-handling method for the batch job. Logs an error message.
    * @param message: The error message to be logged.
    * @return: void
    */
    public void error(String message) {
        System.debug('Error: ' + message);
    }
}
