public with sharing class ConvertFlowMetadata {
 
    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

    @InvocableMethod
    public static List <Results> convert(List<Requests> requestList) {
        System.debug('entering invocable method ConvertFlowMetadata.convert');
        Results response = new Results();
        List<Results> responseWrapper = new List<Results>();
        String flowName;

        for (Requests req : requestList) {
            //System.debug('zip file text is:' + req.flowMetadataZipFile);
            //System.debug('flowname is:' + req.flowName);

            String flowmetadata = unpackZipfile( req.flowMetadataZipFile);
            Account a = new Account();
            a.Id = '0019D00000G9thIQAR';
            a.Test__c = flowmetadata;
            update a;
            //System.debug('initial retrieved unconverted pb metadata is: ' + flowmetadata);
            String validityProblemString = ValidateMetadata.validate (flowmetadata);
            //System.debug('validtyProblemString is: ' + validityProblemString);
            if(validityProblemString == '') {
                String metadataText = convertMetadata(flowmetadata, req.flowName);
                a.Id = '0019D00000G9thIQAR';
                a.Test2__c = metadataText;
                update a;
                response.convertedFlowMetadata = metadataText;
            } else {
                response.errors = validityProblemString;
            }
            
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

    public static String convertMetadata(String metadata, String flowName) {
        Dom.Document doc = new Dom.Document();
        doc.load(metadata);
        Dom.XMLNode flowXML = doc.getRootElement();
       // System.debug('root node is:' + flowXML);
       
        Dom.XmlNode pmv_ObjectType = XmlUtils.getChildProcessMetadataValueByName(flowXML,'ObjectType');
        String contextObjectType = XmlUtils.getProcessMetadataValue(pmv_ObjectType);
        System.debug('contextObjectType for flow: ' + flowName +' is: ' + contextObjectType);

        Dom.XmlNode  pmv_TriggerType = XmlUtils.getChildProcessMetadataValueByName(flowXML,'TriggerType');
        String triggerType = XmlUtils.getProcessMetadataValue(pmv_TriggerType);
        System.debug('triggerType for flow: ' + flowName +' is: ' + triggerType); 
        String startElementReference = flowXML.getChildElement('startElementReference', SOAP_NS).getText();
        String newProcessType = 'AutolaunchedFlow';
        System.debug('pmetdecRefName');
        List<Dom.XmlNode> nodesToREmove = new List<Dom.XmlNode>();
        List<Dom.XmlNode> decisionNodes = XmlUtils.getChildrenByName(flowXml, 'decisions');
        for(Dom.XmlNode decision : decisionNodes) {
            String refName = getDecisionRefName(decision);
            System.debug('pmetdecRefName refname ' + refName);
            if(refName != null && refName.contains('pmetdec')) {
                Dom.XmlNode pmetdec = getDecisionByName(decisionNodes, refName);
                String pmetdecRefName = getDecisionRefName(pmetdec);
                System.debug('pmetdecRefName' + pmetdecRefName);
                Dom.XmlNode parent = pmetdec.getParent();
                System.debug('pmetdec' + pmetdec);
                if(parent != null) {
                    parent.removeChild(pmetdec);
                }
                setDecisionRefName(decision, pmetdecRefName);
               // nodesToREmove.add(pmetdec);

                
                
            }        
        }
        
        flowXML = ModifyFlowMetadata.changeProcessType(flowXML, newProcessType);
        flowXML = ModifyFlowMetadata.setStatus(flowXML, 'Draft' );
        flowXML = ModifyFlowMetadata.addStartElement(flowXML, contextObjectType, triggerType, startElementReference);
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'ObjectType');
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'ObjectVariable');
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'OldObjectVariable');
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'RecursiveCountVariable');
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'TriggerType');
        doc = ModifyFlowMetadata.changeContextReference(doc);  
        doc = ModifyFlowMetadata.fixupRelatedReferences(doc);
        ModifyFlowMetadata.repositionElements(doc);
             
        String classText = doc.toXmlString();
        System.debug('===========');
        System.debug ('following all conversion, is: ' + classText);
        //deployChangedMetadata(classText, flowName, null, 'Flow');    

        return classText;
            
    }

    public static Dom.XmlNode getDecisionByName(List<Dom.XmlNode> decisionList, String name) {
        for(Dom.XmlNode item : decisionList){
            if(XmlUtils.getInternalName(item) == name) {
                return item;
            }
        }
        return null;
    }

    public static String getDecisionRefName(Dom.XmlNode decision) {
        Dom.XmlNode rule = decision.getChildElement('rules', SOAP_NS);
        if(rule != null) {
            Dom.XmlNode connector = rule.getChildElement('connector', SOAP_NS);
            Dom.XmlNode targetReference = connector.getChildElement('targetReference', SOAP_NS);
            String refName = targetReference.getText();
            if(refName != null) {
                return refName;
            }
        }
        return null;
    }

    public static Boolean setDecisionRefName(Dom.XmlNode decision, String refName) {
        Dom.XmlNode rule = decision.getChildElement('rules', SOAP_NS);
        if(rule != null) {
            Dom.XmlNode connector = rule.getChildElement('connector', SOAP_NS);
            Dom.XmlNode targetReference = connector.getChildElement('targetReference', SOAP_NS);
            connector.removeChild(targetReference);
            targetReference = connector.addChildElement('targetReference', SOAP_NS, null);
            targetReference.addTextNode(refName);
            Dom.XmlNode doesRequireRecordChangedToMeetCriteria = rule.addChildElement('doesRequireRecordChangedToMeetCriteria', SOAP_NS, null);
            doesRequireRecordChangedToMeetCriteria.addTextNode('true');
        }
        return null;
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
        public String errors;

       
        @InvocableVariable
        public String convertedFlowMetadata;

    }

    public class PBConvertException extends Exception{}
}