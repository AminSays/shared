public class ArchivalUtility implements Database.Batchable<sObject>, Database.Stateful {
    //To Store log entries
    private List<string> Log {get; set;}
    private List<string> ErrorLog {get; set;}
    private list<string> ErrorIds {get; set;}    
    //To store Process entry record
    private Archival_Process__c objProcess {get; set;}
    //To count number of iterations and errors
    private integer iterationCount {get; set;}
    private integer errorRecCount {get; set;}
    //Constructor to pass process Id
    public ArchivalUtility(id archivalProcessId)
    {
        List<Archival_Process__c> lstProcess = [ SELECT Id, Job_Id__c, Source_Object__c, Target_Object__c, Archived_Till__c, Delete_Records__c, Status__c, Batch_Size__c, Start_Time__c, End_Time__c, Selected__c, Archived__c, Deleted__c, Updated__c, Log__c, Has_Error__c FROM Archival_Process__c WHERE Id = :archivalProcessId AND Status__c = 'Queued'];
        if(lstProcess.size() == 1 )
        {
            objProcess = lstProcess.get(0);
            objProcess.Selected__c = 0;
            objProcess.Archived__c = 0;
            objProcess.Error__c = 0;
            objProcess.Deleted__c = 0;
            objProcess.Updated__c = 0;
            this.Log = new List<string>();
            this.ErrorLog = new List<string>();
            iterationCount = 0;
            errorRecCount = 0;
    	}
        else
        {
            objProcess = null;
            throw new ProcessException('No queued process not found with specified id: ' + archivalProcessId);
        }
    }
    //Start method to select records to be processed
    public Database.QueryLocator start(Database.BatchableContext bc) {
        objProcess.Job_Id__c = bc.getJobId();
        try
        {
            startProcessEntry();
			addToLog('Process Started', false);
            string strQuery = '';
            switch on objProcess.Source_Object__c.toUpperCase()
            {
                when 'CASE'
                {
                    strQuery = getCaseQuery();
                }
                when 'LEAD'
                {
                    strQuery = getLeadQuery();
                }
                when else
                {
					addToLog('No query defined for source object: ' + objProcess.Source_Object__c, true);
                }
            }
            
            Date tillDate = objProcess.Archived_Till__c.addDays(1);//required to pass parameter to query, adding one day and using < to avoid date time convesion issue
            return Database.getQueryLocator(strQuery);
        }
        catch(Exception ex)
        {
			addToLog(ex.getMessage(), true);
            System.debug('start: ' + ex.getMessage());
            throw ex;
        }
    }
    //Execute iteration to process batch of records
    public void execute(Database.BatchableContext bc, List<sObject> source) {
        string jobId = bc.getJobId();
        ++iterationCount;
        boolean hasError = false;
		addToLog('Itr ' + iterationCount + ': Start: ' + source.size(), false);
        List<sObject> lstTarget = new List<sObject>();
        try
        {
			objProcess.Selected__c = objProcess.Selected__c + source.size();
            
            for(sObject objSource : source)
            {
                if ( objSource instanceof Case)
                {
	                lstTarget.add(mapCase((Case) objSource));
                    ((Case) objSource).Archived__c = true;
                }
                else if ( objSource instanceof Lead )
                {
					lstTarget.add(mapLead((Lead) objSource));
                    ((Lead) objSource).Archived__c = true;
                }
                else
                    return;
            }
            
            //Insert in BO
            hasError = insertTarget(lstTarget, source, hasError);
            
            //Update to set flag as archived
            updateSource(source, hasError);
            
            //Delete if user chose to delete
            if(objProcess.Delete_Records__c)
	            deleteSource(source, hasError);
        }
        catch(Exception ex)
        {
            addToLog('Itr ' + iterationCount + ': Exception: ' + ex.getMessage(), true);
            System.debug('execute: ' + ex.getMessage());
        }
        finally
        {
            if(hasError)
                addToLog('Itr ' + iterationCount + ': Success', false);
            else
	            addToLog('Itr ' + iterationCount + ': Complete', false);
            
            //updated Archive Process records
			objProcess.Log__c = string.join(Log, '\n');
			objProcess.Error_Log__c = string.join(ErrorLog, '\n');            
			update objProcess;
        }
    }
    //Finish method to complete the process
    public void finish(Database.BatchableContext bc) {
        addToLog('Finishing Job.', false);
        finishProcessEntry();
    }
    //Method to insert in BO
    private boolean insertTarget(List<sObject> target, List<sObject> source, boolean hasError)
    {
        List<Database.SaveResult> lstResult = Database.insertImmediate(target);
        List<string> errors = getErrors(lstResult, source);
        
        if(errors.size() == 0)
        {
            hasError = false;
            objProcess.Archived__c = objProcess.Archived__c + target.size();
            addToLog('Insert done.', false);
        }
        else
        {
            hasError = true;
            ErrorLog.add('Itr (' + iterationCount +'): Insert errors:');
            ErrorLog.addAll(errors);
            objProcess.Archived__c = objProcess.Archived__c + target.size() - errorRecCount;
            objProcess.Error__c = objProcess.Error__c + errorRecCount;
            addToLog('Inserts except errors: ' + (target.size() - errorRecCount), true);
        }
        return hasError;
    }
    private void updateSource(List<sObject> source, boolean hasError)
    {
        List<Database.SaveResult> lstResult;
        integer recTried = source.size();
        if(hasError)
        {
            List<sObject> selected = new List<sObject>();
            for(sObject objSource : source)
            {
                if (! ErrorIds.contains(objSource.get('Id').toString()))
                {
                    selected.add(objSource);
                }
            }
            recTried = selected.size();
            lstResult = Database.updateImmediate(selected, System.AccessLevel.SYSTEM_MODE);
        }
        else
        {
            lstResult = Database.updateImmediate(source, System.AccessLevel.SYSTEM_MODE);
        }
        if(lstResult != null)
        {      
            List<string> errors = getErrors(lstResult, source);
            if(errors.size() == 0)
            {
                objProcess.Updated__c = objProcess.Updated__c + recTried;
                addToLog('Update done: ' + recTried, false);
            }
            else
            {
                ErrorLog.add('Itr (' + iterationCount +'): Update errors:');
                ErrorLog.addAll(errors);
                objProcess.Updated__c = objProcess.Updated__c + recTried - errorRecCount;
                objProcess.Error__c = objProcess.Error__c + errorRecCount;                    
                addToLog('Updates except errors: ' + (recTried - errors.size()), true);
            }
        }
    }
    
    private void deleteSource(List<sObject> source, boolean hasError)
    {
        List<Database.DeleteResult> lstResult;
        integer recTried = source.size();
        if(hasError)
        {
            List<sObject> selected = new List<sObject>();
            for(sObject objSource : source)
            {
                if (! ErrorIds.contains(objSource.get('Id').toString()))
                {
                    selected.add(objSource);
                }
            }
            recTried = selected.size();
            lstResult = Database.deleteImmediate(selected, System.AccessLevel.SYSTEM_MODE);
        }
        else
        {
        	lstResult = Database.deleteImmediate(source, System.AccessLevel.SYSTEM_MODE);
        } 
        
        List<string> errors = getErrors(lstResult, source);
        
        if(errors.size() == 0)
        {
            	objProcess.Deleted__c = objProcess.Deleted__c + recTried;
            	addToLog('Delete done: ' + recTried , false);
        }
        else
        {
            ErrorLog.add('Itr (' + iterationCount +'): errors in Delete:');
            ErrorLog.addAll(errors);
            objProcess.Deleted__c = objProcess.Deleted__c + recTried - errorRecCount;
            objProcess.Error__c = objProcess.Error__c + errorRecCount;                    
            addToLog('Deletes except errors: ' + (recTried - errors.size()) , true);
        }
    }
    
    //Method to append Log entry
    private void addToLog(string message, boolean hasError)
    {
        Log.add(DateTime.now() + ' : ' + message);
		if( hasError && ! objProcess.Has_Error__c )
        	objProcess.Has_Error__c = hasError;
    }
    //Method to get error records from Save result
    private List<string> getErrors(List<Database.SaveResult> results, List<sObject> source)
    {
        List<string> lstErrors = new List<string>();
        integer i = 0;
        errorRecCount =0;
        ErrorIds = new List<String>();
        sObject objSource;
        for(Database.SaveResult result : results)
        {
            if(!result.isSuccess())
            {
                errorRecCount++;
                objSource = source.get(i);
                ErrorIds.add(objSource.get('id').toString());
                
             	for(Database.Error error : result.getErrors())
                {
					lstErrors.add(objSource.get('id') + ': ' + error.getStatusCode() + ': ' + error.getMessage());
                }
            }
            i++;
        }
        return lstErrors;
    }
    //Method to get error records from Delete Result
    private List<string> getErrors(List<Database.DeleteResult> results, List<sObject> source)
    {
        List<string> lstErrors = new List<string>();
        integer i = 0;
        errorRecCount = 0;
        sObject objSource;      
        for(Database.DeleteResult result : results)
        {
            if(! result.isSuccess())
            {
                errorRecCount++;
                objSource = source.get(i);
             	for(Database.Error error : result.getErrors())
                {
					lstErrors.add(objSource.get('id') + ': ' + error.getStatusCode() + ': ' + error.getMessage());
                }
            }
            i++;
        }
        return lstErrors;
    }
    //Method to return SOQL for Case object
    private static string getCaseQuery()
    {
        return 'SELECT Id, CaseNumber, AccountId, Origin, Reason, RecordType.Name, SourceId, ContactEmail, ContactMobile, ContactId, CreatedById, ClosedDate, CreatedDate, Description, IsEscalated, External_ID__c, Comments, Status, Subject, Type, SuppliedEmail, SuppliedPhone, SuppliedName, ParentId, Priority FROM Case WHERE Archived__c = false AND CreatedDate < :tillDate';
    }
    //Method to return SOQL for Lead object
    private static string getLeadQuery()
    {
        return 'SELECT Id, LastName, FirstName, Salutation, Title, Company, Street, City, State, PostalCode, Country, Latitude, Longitude, GeocodeAccuracy, Phone, MobilePhone, Fax, Email, Website, PhotoURL, Description, LeadSource, Status, Industry, Rating, AnnualRevenue, NumberOfEmployees, OwnerId, HasOptedOutOfEmail, IsConverted, ConvertedDate, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId, CreatedDate, CreatedById, DoNotCall, IndividualId, External_Id__c FROM Lead WHERE Archived__c = false AND CreatedDate < :tillDate';
    }
    //Method to cast Case object to Case big object
    private static Case__b mapCase(Case objCase)
    {
        Case__b objCaseB = new Case__b();
        objCaseB.RecordId__c = objCase.Id;
        objCaseB.AccountId__c = objCase.AccountId;
        objCaseB.CaseNumber__c = objCase.CaseNumber;
        objCaseB.ClosedDate__c = objCase.ClosedDate;
        objCaseB.Comments__c = objCase.Comments;
        objCaseB.ContactEmail__c = objCase.ContactEmail;
        objCaseB.ContactId__c = objCase.ContactId;
        objCaseB.ContactMobile__c = objCase.ContactMobile;
        objCaseB.CreatedById__c = objCase.CreatedById;
        objCaseB.CreatedDate__c = objCase.CreatedDate;
        objCaseB.Description__c = objCase.Description;
        objCaseB.External_ID__c = objCase.External_ID__c;
        if( objCase.IsEscalated == true)
        	objCaseB.IsEscalated__c = 1;
        else
            objCaseB.IsEscalated__c = 0;
        objCaseB.Origin__c = objCase.Origin;
        objCaseB.ParentId__c = objCase.ParentId;
        objCaseB.Priority__c = objCase.Priority;
        objCaseB.Reason__c = objCase.Reason;
        objCaseB.RecordType__c = objCase.RecordTypeId;
        objCaseB.Source__c = objCase.SourceId;
        objCaseB.Status__c = objCase.Status;
        objCaseB.Subject__c = objCase.Subject;
        objCaseB.SuppliedEmail__c = objCase.SuppliedEmail;
        objCaseB.SuppliedName__c = objCase.SuppliedName;
        objCaseB.SuppliedPhone__c = objCase.SuppliedPhone;
    	return objCaseB;
    }
    //Method to cast Lead object to Lead big object
    private static Lead__b mapLead(Lead objLead)
    {
        Lead__b objLeadB = new Lead__b();
        objLeadB.Id__c = objLead.Id;
        objLeadB.LastName__c = objLead.LastName;
        objLeadB.FirstName__c = objLead.FirstName;
        objLeadB.Salutation__c = objLead.Salutation;
        objLeadB.Title__c = objLead.Title;
        objLeadB.Company__c = objLead.Company;
        objLeadB.Street__c = objLead.Street;
 		objLeadB.City__c = objLead.City;
        objLeadB.State__c = objLead.State;
        objLeadB.PostalCode__c = objLead.PostalCode;
        objLeadB.Country__c = objLead.Country;
        objLeadB.Latitude__c = objLead.Latitude;
        objLeadB.Longitude__c = objLead.Longitude;
        objLeadB.GeocodeAccuracy__c = objLead.GeocodeAccuracy;
        objLeadB.Phone__c = objLead.Phone;
        objLeadB.MobilePhone__c = objLead.MobilePhone;
        objLeadB.Fax__c = objLead.Fax;
        objLeadB.Email__c = objLead.Email;
        objLeadB.Website__c = objLead.Website;
        objLeadB.PhotoURL__c = objLead.PhotoURL;
        objLeadB.Description__c = objLead.Description;
        objLeadB.LeadSource__c = objLead.LeadSource;
        objLeadB.Status__c = objLead.Status;
        objLeadB.Industry__c = objLead.Industry;
        objLeadB.Rating__c = objLead.Rating;
        objLeadB.AnnualRevenue__c = objLead.AnnualRevenue;
        objLeadB.NumberOfEmployees__c = objLead.NumberOfEmployees;
        objLeadB.OwnerId__c = objLead.OwnerId;
        if( objLead.HasOptedOutOfEmail == true )
        	objLeadB.HasOptedOutOfEmail__c = 1;
        else
            objLeadB.HasOptedOutOfEmail__c = 0;
        if( objLead.IsConverted == true )
        	objLeadB.IsConverted__c = 1;
        else
        	objLeadB.IsConverted__c = 0;
        
        objLeadB.ConvertedDate__c = objLead.ConvertedDate;
        objLeadB.ConvertedAccountId__c = objLead.ConvertedAccountId;
        objLeadB.ConvertedContactId__c = objLead.ConvertedContactId;
        objLeadB.ConvertedOpportunityId__c = objLead.ConvertedOpportunityId;
        objLeadB.CreatedDate__c = objLead.CreatedDate;
        objLeadB.CreatedById__c = objLead.CreatedById;
		if (objLead.DoNotCall == true )
	        objLeadB.DoNotCall__c = 1;
        else
	        objLeadB.DoNotCall__c = 0;
        objLeadB.IndividualId__c = objLead.IndividualId;
        objLeadB.External_Id__c = objLead.External_Id__c;
    	return objLeadB;
    }
    //Method to set status and Start Time for Process entry
    private void startProcessEntry()
    {
        if(objProcess != null)
        {
            objProcess.Start_Time__c = DateTime.now();
            objProcess.Status__c = 'Started';
            update objProcess;
        }
        else
        {
            throw new ProcessException('startProcessEntry: Process entry not started.');
        }
    }
    //Method to set status, End Time and Log for Process entry    
    private void finishProcessEntry()
    {
        if(objProcess != null)
        {
            objProcess.Status__c = 'Finished';
            objProcess.End_Time__c = DateTime.now();
            objProcess.Log__c = string.join(Log, '\n');
			update objProcess;
        }
        else
        {
			throw new ProcessException('finishProcessEntry: Process entry not finished.');
        }
    }
    //Custom Exception
    private virtual class ProcessException extends Exception {}
}