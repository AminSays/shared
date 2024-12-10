%dw 2.6
input records application/csv
output application/apex
---
records map(record) -> {
 External_Id__c: record.Id,
 Case_Number__c: record.CaseNumber,
 Subject__c: record.Subject,
 Description__c: record.Description
} as Object {class: "Case__c"}