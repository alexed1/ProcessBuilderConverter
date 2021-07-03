@isTest
public with sharing class ConvertWFRMetadataTest {
  @isTest
  static void convertTest() {
    StaticResource sr = [SELECT Id, Body FROM StaticResource WHERE Name = 'ValidWorkflow' LIMIT 1];
    ConvertWFRMetadata.Requests request = new ConvertWFRMetadata.Requests();
    request.wfrMetadataZipFile = sr.Body.toString();
    request.wfrName = 'Account.UpdateField';
    ConvertWFRMetadata.Results result = ConvertWFRMetadata.convert(new List<ConvertWFRMetadata.Requests> {request})[0];

    System.assert(result.convertedFlowMetadata != null);
  }
}
