   @isTest 
   public with sharing class ValidateMetadataTest { 

   @isTest
   public static void validationRejectsIsChanged() {
        String flowMetadata = getMetadataString();
        String validationString = ValidateMetadata.validate(flowMetadata);
        
        System.assertNotEquals(null,validationString);
   }

 
    public static String getMetadataString() {
      StaticResource testData = [SELECT Id, Body FROM StaticResource WHERE Name = 'InvalidPB' LIMIT 1];
      string metadata = testData.Body.toString();
      return metadata;
    }
   }