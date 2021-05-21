@isTest
public class ConvertFlowMetadataTest {
    @isTest
    public static void testConvertMetadata(){
        String metadata = getMetadata();
        String conversionString = ConvertFlowMetadata.convertMetadata(metadata, 'Test_Process');
        system.assertNotEquals(null,conversionString);
    }
    
    public static String getMetadata(){
        StaticResource testData = [SELECT Id, Body FROM StaticResource WHERE Name = 'TestProcess' LIMIT 1];
        string metadata = testData.Body.toString();
        return metadata;
    }
 }