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

    public static Dom.XmlNode addStartElement(Dom.XmlNode flowXML) {
        
        Dom.XmlNode curNode = flowXML.addChildElement('start', SOAP_NS, null);
        
        //System.debug('processType is: ' + curNode.getText());
        //curNode = XmlUtils.changeTextValue(newProcessType, curNode);
        //curNode = flowXML.getChildElement('processType',  SOAP_NS);         
        //System.debug('processType is now : ' + curNode.getText());
        return flowXML;
    }

}
