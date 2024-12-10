%dw 2.6
input records application/csv
output application/apex
---
records map(record) -> {
    Batch_Export__c : record.Batch_Export_Id__c,
    Case_Number__c : record.Case_Number__c,
    Closed_Date__c : record.Closed_Date__c as DateTime {format : "yyyy-MM-dd'T'HH:mm:ss.SSSX"},
    Comments__c : record.Comments__c,
    Contact_Fax__c : record.Contact_Fax__c,
    Contact_Id__c : record.Contact_Id__c,
    Created_Date__c : record.Created_Date__c as DateTime {format : "yyyy-MM-dd'T'HH:mm:ss.SSSX"},
    Description__c : record.Description__c,
    External_Id__c : record.External_Id__c,
    Origin__c : record.Origin__c,
    Parent_Id__c : record.Parent_Id__c,
    Priority__c : record.Priority__c,
    Reason__c : record.Reason__c,
    Source__c : record.Source__c,
    Status__c : record.Status__c,
    Subject__c : record.Subject__c,
    Supplied_Company__c : record.Supplied_Company__c,
    Supplied_Email__c : record.Supplied_Email__c,
    Supplied_Name__c : record.Supplied_Name__c,
    Supplied_Phone__c : record.Supplied_Phone__c,
    Type__c : record.Type__c
} as Object {class: "Case__c"}
