public with sharing class GetMetadata {

 
        @InvocableMethod
        public static List <Results> get(List<Requests> requestList) {
            Results response = new Results();
            List<Results> responseWrapper = new List<Results>();
            
            for (Requests req : requestList) {
                String name = req.name;
                String objectType = req.objectType;

                MetadataService.MetadataPort service = createService();	
                MetadataService.ListMetadataQuery mdQuery = new MetadataService.ListMetadataQuery();
                mdQuery.type_x = 'Flow';
                MetadataService.ListMetadataQuery[] mdqList = new MetadataService.ListMetadataQuery[] {};
                mdqList.add(mdQuery);
                Double mdVersion = 37.0;
                MetadataService.FileProperties[] fpList = service.listMetadata(mdqList, mdVersion);
                System.debug('@@@ metadata result size = ' + fpList.size());
                for (MetadataService.FileProperties fp: fpList) {
                    System.debug('@@@ Flow name: ' + fp.fullName);
                }

                String[] flowNameArray = new List<String>();
                //flowNameArray.add(req.name); 
                flowNameArray.add('Testproc_One-1');
                MetadataService.Flow flow =
                            (MetadataService.Flow) service.readMetadata('Flow',flowNameArray).getRecords()[0];
                
                System.debug('Name ' + flow.FullName);
                System.debug('recordCreate ' + flow.recordCreates);
    
    
                response.XMLText = flow.FullName;
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
           
            @InvocableVariable 
            public String name;
    
            @InvocableVariable 
            public String objectType;
    
        }
    
        public class Results {
    
           
            @InvocableVariable
            public String XMLText;
    
        }
    }
    