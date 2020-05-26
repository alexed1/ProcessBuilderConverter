public with sharing class ModifyFlowMetadata {

    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';
   
    public static Dom.XmlNode changeProcessType(Dom.XmlNode flowXML, String newProcesstype) {
        
        Dom.XmlNode curNode = flowXML.getChildElement('processType',  SOAP_NS);
        
        System.debug('processType is: ' + curNode.getText());
        curNode = XmlUtils.changeTextValue(newProcessType, curNode);
        //curNode = flowXML.getChildElement('processType',  SOAP_NS);         
        //System.debug('processType is now : ' + curNode.getText());
        return flowXML;
    }

    public static Dom.XmlNode setStatus(Dom.XmlNode flowXML, String newStatus) {
        
        Dom.XmlNode curNode = flowXML.getChildElement('status',  SOAP_NS);
        
        System.debug('status is: ' + curNode.getText());
        curNode = XmlUtils.changeTextValue(newStatus, curNode);
        //curNode = flowXML.getChildElement('processType',  SOAP_NS);         
        //System.debug('processType is now : ' + curNode.getText());
        return flowXML;
    }

    public static void deleteSelf(Dom.XmlNode curNode) {
        curNode.getParent().removeChild(curNode);
    }

    //delete the variable myVariable_current
    //change all existing myVariable_current references to $Record
    public static Dom.Document changeContextReference(Dom.Document doc) {
        
    
        Dom.XMLNode flowXML = doc.getRootElement();

        List<Dom.XmlNode> allNodes = flowXML.getChildren();
        List<Dom.XmlNode> variableNodes = new List<Dom.XmlNode>();
        for ( Dom.XmlNode curNode : allNodes) {
            if(curNode.getName() == 'variables'){
                variableNodes.add(curNode);
            }
        }
        for (Dom.XmlNode curNode : variableNodes) {
            if (curNode.getChildElement('name', SOAP_NS).getText() == 'myVariable_current')
                deleteSelf(curNode);
        }
        
        //find and replace
        String metadataString = doc.toXmlString();
        metadataString = metadataString.replace('myVariable_current', '$Record');
        System.debug('metadatastring is: ' + metadataString);
        Dom.Document convertedDoc = new Dom.Document();
        convertedDoc.load(metadataString);
        return convertedDoc;
        
    }

    public static Dom.Document fixupRelatedReferences(Dom.Document doc) {
        
        //find and replace
        String metadataString = doc.toXmlString();
        metadataString = metadataString.replace('Owner.Id', 'OwnerId');
        metadataString = metadataString.replace('User.Id', 'UserId');
        //System.debug('metadatastring is: ' + metadataString);
        Dom.Document convertedDoc = new Dom.Document();
        convertedDoc.load(metadataString);
        return convertedDoc;
        
    }

    public static Dom.XmlNode addStartElement(Dom.XmlNode flowXML, String contextObjectType, String triggerType, String startElementReference) {
        DOM.Document doc = new DOM.Document();
        //String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
        //dom.XmlNode startHolder = doc.createRootElement('startHolder', SOAP_NS, '');
        System.debug('startElementReference is: ' + startElementReference);
        Dom.XmlNode oldStartReference = flowXML.getChildElement('startElementReference', SOAP_NS);
        flowXML.removeChild(oldStartReference);
        Dom.XmlNode startNode = flowXML.addChildElement('start', SOAP_NS, null);
        
        startNode.addChildElement('locationX', SOAP_NS, null).addTextNode('43');
        startNode.addChildElement('locationY', SOAP_NS, null).addTextNode('43');
        startNode.addChildElement('connector', SOAP_NS, null).addChildElement('targetReference', SOAP_NS, null).addTextNode(startElementReference);
        startNode.addChildElement('object', SOAP_NS, null).addTextNode(contextObjectType);
        startNode.addChildElement('recordTriggerType', SOAP_NS, null).addTextNode('Create');
        startNode.addChildElement('triggerType', SOAP_NS, null).addTextNode('RecordAfterSave');
        


        //System.debug ('flowxml with start is: ' + flowXML);
        
        return flowXML;
    }

}
