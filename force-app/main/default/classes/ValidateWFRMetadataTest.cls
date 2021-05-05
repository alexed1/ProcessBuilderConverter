@isTest
public with sharing class ValidateWFRMetadataTest {
    

    @isTest
    public static void CanGetRulesEntity() {
        StaticResource sr = [SELECT Id, Body FROM StaticResource WHERE Name = 'InvalidWorkflow' LIMIT 1];
        Dom.Document doc = new Dom.Document();
        doc.load(sr.Body.toString());
        Dom.XmlNode wfrNode = doc.getRootElement();
        //check worflow with unsupported elementes
        String result = ValidateWFRMetadata.validateRule(wfrNode, 'Account.Test Workflow');
        System.debug('result' + result);
        System.assert(String.isNotBlank(result) );
        
    }


   
}
