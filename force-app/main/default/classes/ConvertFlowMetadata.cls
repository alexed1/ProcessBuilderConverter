public with sharing class ConvertFlowMetadata {
 
    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

    @InvocableMethod
    public static List <Results> convert(List<Requests> requestList) {
        Results response = new Results();
        List<Results> responseWrapper = new List<Results>();
        String flowName;

        for (Requests req : requestList) {
            System.debug('zip file text is:' + req.flowMetadataZipFile);
            System.debug('flowname is:' + req.flowName);

             
            Blob zipBlob = EncodingUtil.base64Decode(req.flowMetadataZipFile);
            Zippex curZippex = new Zippex(zipBlob);
            Set<String> fileNames = curZippex.getFileNames();
            System.debug('filenames are: ' + fileNames);
         
            List<String> filenamesList = new List<String>(fileNames);



            
               //currently only set up to handle a single file
            Blob fileData = curZippex.getFile(filenamesList[0]);
            System.debug ('filename: ' + filenamesList[0]);
            String flowmetadata = fileData.toString();
            //System.debug ('file: '+  flowmetadata);
            response.convertedFlowMetadata = flowmetadata;
            String metadataText = convertToXML(flowmetadata, req.flowName);
            response.convertedFlowMetadata = metadataText;
            responseWrapper.add(response);
        }
        return responseWrapper;
        


    }

    public static String convertToXML(String metadata, String flowName) {
        Dom.Document doc = new Dom.Document();
        doc.load(metadata);
        //Retrieve the root element for this document.

        Dom.XMLNode flowXML = doc.getRootElement();
        System.debug('root node is:' + flowXML);
        System.debug('CHILDREN........');

        
       /*  String contextObjectType = getProcessMetadataValue(flowXML,'ObjectType');
        System.debug('contextObjectType for flow: ' + flowName +' is: ' + contextObjectType);
        String triggerType = getProcessMetadataValue(flowXML,'TriggerType');
        System.debug('triggerType for flow: ' + flowName +' is: ' + triggerType); */

        String newProcessType = 'AutolaunchedFlow';
        flowXML = ModifyFlowMetadata.changeProcessType(flowXML, newProcessType);
        //flowXML = ModifyFlowMetadata.addStartElement(flowXML);
                  
        String classText = doc.toXmlString();
        deployChangedMetadata(classText, flowName, null, 'Flow');         
        return classText;
            
    }

    public static String getProcessMetadataValue(Dom.XmlNode flowXML, String pmvTargetName) {
        for(Dom.XMLNode pmv : flowXML.getChildElements()) {
            System.debug('current child element of flow is: ' + pmv);
            if (pmv.getName() == 'processMetadataValues') {
                System.debug ('this one has the name processMetadataValue'); 
                for (Dom.XMLNode pmvChild : pmv.getChildElements()){
                    System.debug('the current child of the processmetadatavalue element is ' + pmvChild);
                    if (pmvChild.getName() == 'name') {
                        System.debug ('this child is named name');
                        if (pmvChild.getText() == pmvTargetName) {
                            System.debug ('theres a match between the value of this element and the passed in value: ' + pmvTargetName);
                            String targetValue;
                            Dom.XmlNode pmvValueElement = pmv.getChildElement('value', SOAP_NS);
                            if (pmvValueElement.getChildElement('elementReference', SOAP_NS) != null) {
                                targetValue = pmvValueElement.getChildElement('elementReference', SOAP_NS).getText();
                            } else {
                                targetValue = pmvValueElement.getChildElement('stringValue', SOAP_NS).getText();
                            }
                            System.debug('targetValue is: ' + targetValue);
                            return targetValue;
                        }
                    }
                }
            }
            
        }
        return 'not found in processMetadataValue';
    }

    public static void deployChangedMetadata(String classText, String className, String testLevel, String objectType) {

        DeployMetadata.deploy(classText, className, testLevel, objectType);


    }

 
    

    public class Requests {
       
        @InvocableVariable 
        public String flowName;

        @InvocableVariable 
        public String flowMetadataZipFile;

       

      

    }

    public class Results {

       
        @InvocableVariable
        public String convertedFlowMetadata;

    }
}