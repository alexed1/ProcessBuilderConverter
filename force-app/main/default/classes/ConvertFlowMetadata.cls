public with sharing class ConvertFlowMetadata {

    @InvocableMethod
    public static List <Results> get(List<Requests> requestList) {
        Results response = new Results();
        List<Results> responseWrapper = new List<Results>();
        
        for (Requests req : requestList) {

            MetadataService.Flow  curFlow = req.initialFlowMetadata;

            if (!String.isEmpty(req.newFlowName))
                curFlow.fullName = req.newFlowName;
            if (!String.isEmpty(req.newFlowLabel))  
                curFlow.label = req.newFlowLabel;
            if (!String.isEmpty(req.newFlowProcessType))
                curFlow.processType = req.newFlowProcessType;

            //this doesn't work yet because the MetadataService included in the project has not been properly upgraded to reflect recent api changes that added the FlowStart element
            // curFlow.start = new MetadataService.FlowStart();
            // curFlow.start.triggerType ='RecordBeforeSave';
            // curFlow.start.recordTriggerType = 'CreateAndUpdate';

            response.convertedFlowMetadata = curFlow;
            responseWrapper.add(response);
        }
        return responseWrapper;


    }

   
    

    public class Requests {
       
        @InvocableVariable 
        public String newFlowName;

        @InvocableVariable 
        public String newFlowLabel;

        @InvocableVariable 
        public String newFlowProcessType;

        @InvocableVariable(required=true)
        public MetadataService.Flow initialFlowMetadata;

    }

    public class Results {

       
        @InvocableVariable
        public MetadataService.Flow convertedFlowMetadata;

    }
}