public with sharing class ReadMetadata {
    public ReadMetadata() {

    }
    private static final Integer METADATA_API_VERSION = 48;

    public static void read() {
        
        MetadataService.MetadataPort service = createService();			
       // String target = 'SampleFlow_RecordChangeBeforeSave';
        String target = 'Testproc_One';
        MetadataService.Flow flow = (MetadataService.Flow) service.readMetadata('Flow', new String[] { target }).getRecords()[0];
        System.debug('flow is:' + flow);
    }

    private static MetadataService.MetadataPort createService()
	{ 
		MetadataService.MetadataPort service = new MetadataService.MetadataPort();
		service.SessionHeader = new MetadataService.SessionHeader_element();
		service.SessionHeader.sessionId = UserInfo.getSessionId();
		return service;		
    }	
}
