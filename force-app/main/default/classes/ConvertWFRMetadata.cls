public with sharing class ConvertWFRMetadata {
 
    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

    @InvocableMethod
    public static List <Results> convert(List<Requests> requestList) {
        System.debug('entering invocable method ConvertWFRMetadata.convert');
        Results response = new Results();
        List<Results> responseWrapper = new List<Results>();
        //String flowName;

        for (Requests req : requestList) {
            System.debug('zip file text is:' + req.wfrMetadataZipFile);
            System.debug('wfrname is:' + req.wfrName);

            String wfrmetadata = unpackZipfile( req.wfrMetadataZipFile);
            System.debug('initial retrieved unconverted wfr metadata is: ' + wfrmetadata);


            Dom.Document doc = new Dom.Document();
            doc.load(wfrmetadata);
            Dom.XMLNode wfrXML = doc.getRootElement();


            String validityProblemString = ValidateWFRMetadata.validateRule (wfrXML, req.wfrName);
            //String validityProblemString = '';
            System.debug('validtyProblemString is: ' + validityProblemString);
            if(validityProblemString == '') {
                response.convertedFlowMetadata = convertMetadata(wfrXML, req.wfrName);
            } else {
                response.errors = validityProblemString;
            } 
            //response.convertedFlowMetadata = wfrmetadata;
            responseWrapper.add(response);
        }
        return responseWrapper;
    }

    public static String unpackZipfile(String metadataZipfile) {

             
        Blob zipBlob = EncodingUtil.base64Decode(metadataZipfile);
        Zippex curZippex = new Zippex(zipBlob);
        Set<String> fileNames = curZippex.getFileNames();
        System.debug('filenames are: ' + fileNames);
     
        List<String> filenamesList = new List<String>(fileNames);

           //currently only set up to handle a single file
        Blob fileData = curZippex.getFile(filenamesList[0]);
        System.debug ('filename: ' + filenamesList[0]);
        return  fileData.toString();
    }

    public static String convertMetadata(Dom.XmlNode wfrXML, String wfrName) {
       
       // System.debug('root node is:' + wfrXML);
       
        //Dom.XmlNode pmv_ObjectType = XmlUtils.getChildProcessMetadataValueByName(wfrXML,'ObjectType');
        //String contextObjectType = XmlUtils.getProcessMetadataValue(pmv_ObjectType);
        //System.debug('contextObjectType for flow: ' + flowName +' is: ' + contextObjectType);

        //Dom.XmlNode  pmv_TriggerType = XmlUtils.getChildProcessMetadataValueByName(wfrXML,'TriggerType');
       // String triggerType = XmlUtils.getProcessMetadataValue(pmv_TriggerType);
        //System.debug('triggerType for flow: ' + flowName +' is: ' + triggerType); 
        //String startElementReference = wfrXML.getChildElement('startElementReference', SOAP_NS).getText();
       // String newProcessType = 'AutolaunchedFlow';
        
    /*     wfrXML = ModifyFlowMetadata.changeProcessType(wfrXML, newProcessType);
        wfrXML = ModifyFlowMetadata.setStatus(wfrXML, 'Draft' );
        wfrXML = ModifyFlowMetadata.addStartElement(wfrXML, contextObjectType, triggerType, startElementReference);
        ModifyFlowMetadata.removeExcessPMV(wfrXML, 'ObjectType');
        ModifyFlowMetadata.removeExcessPMV(wfrXML, 'ObjectVariable');
        ModifyFlowMetadata.removeExcessPMV(wfrXML, 'OldObjectVariable');
        ModifyFlowMetadata.removeExcessPMV(wfrXML, 'RecursiveCountVariable');
        ModifyFlowMetadata.removeExcessPMV(wfrXML, 'TriggerType');
        doc = ModifyFlowMetadata.changeContextReference(doc);  
        doc = ModifyFlowMetadata.fixupRelatedReferences(doc);
        ModifyFlowMetadata.repositionElements(doc); */

        //workflow metadata contains multiple rules. we will convert one at a time based on name
        Dom.XMLNode rulesEntity = ValidateWFRMetadata.getRulesEntity(wfrXML);
             
        String classText = ''; //doc.toXmlString();
        System.debug('===========');
        System.debug ('following all conversion, is: ' + classText);
        //deployChangedMetadata(classText, flowName, null, 'Flow');         
        return classText;
            
    }
 

    public static void deployChangedMetadata(String classText, String className, String testLevel, String objectType) {

        DeployMetadata.deploy(classText, className, testLevel, objectType);


    }

 
    

    public class Requests {
       
        @InvocableVariable 
        public String wfrName;

        @InvocableVariable 
        public String wfrMetadataZipFile;

       

      

    }

    public class Results {

        @InvocableVariable
        public String errors;

       
        @InvocableVariable
        public String convertedFlowMetadata;

    }

    public class WFRConvertException extends Exception{}
}