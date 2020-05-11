public with sharing class UpdateMetadata {

    @InvocableMethod
    public static List<Results> execute(List<Requests> requestList) {
        Results response = new Results();
        List<Results> responseWrapper = new List<Results>();
        
        for (Requests req : requestList) {
            MetadataService.Flow flowMetadata = req.flowMetadata;
            MetadataService.MetadataPort service = createService();	
            
            try
            {
                FlowService.saveFlow(service, flowMetadata);
            }
            catch(Exception exc) {
                response.errors = 'Something went wrong:  error: ' + exc.getMessage();
            }
            
            responseWrapper.add(response);
        }
        return responseWrapper;

    }

    public static MetadataService.MetadataPort createService()
    { 
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        return service;		
    }
    

    public class Requests {
       
        @InvocableVariable(required=true)
        public MetadataService.Flow flowMetadata;

    }

    public class Results {
       
       @InvocableVariable
       public String errors;
       

    }
}

