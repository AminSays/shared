public class ActionExecuteArchival {
    @InvocableMethod(label='Action Execute Archival' description='Action to execute archival batch process.' category='Big Objects')
    public static void executeArchival(List<Id> archivalProcessIds) {
        Id processId = archivalProcessIds.get(0);
        List<Archival_Process__c> lstProcess = [ SELECT Id, Job_Id__c, Source_Object__c, Target_Object__c, Archived_Till__c, Delete_Records__c, Status__c, Batch_Size__c, Start_Time__c, End_Time__c, Selected__c, Archived__c, Deleted__c, Updated__c, Log__c, Has_Error__c FROM Archival_Process__c WHERE Id = :processId AND Status__c = 'Queued'];

        if(lstProcess.size() == 1 )
        {
            Archival_Process__c objProcess = lstProcess.get(0);
        	ArchivalUtility objAu = new ArchivalUtility(objProcess.Id);
        	Database.executeBatch(objAu, Integer.valueOf(objProcess.Batch_Size__c));
        }
    }
}