public with sharing class XmlUtils {

    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

   
    public static Dom.XmlNode changeTextValue(String newTextValue, Dom.XmlNode curNode) {
        List<Dom.XmlNode> childList = curNode.getChildren();
        for (Dom.XmlNode curChild : childList) {
            if (curChild.getNodeType().name() == 'TEXT') {
                curNode.removeChild(curChild);
                curNode.addTextNode(newTextValue);
            }
        }
        return curNode;
    }


    public static String getProcessMetadataValue(Dom.XmlNode curPMV) {
        String targetValue;
       // System.debug ('curPMV is: ' + curPMV);
        Dom.XmlNode pmvValueElement = curPMV.getChildElement('value', SOAP_NS);
       // System.debug ('pmvValueElement is: ' + pmvValueElement);
        if (pmvValueElement.getChildElement('elementReference', SOAP_NS) != null) {
            targetValue = pmvValueElement.getChildElement('elementReference', SOAP_NS).getText();
        } else if (pmvValueElement.getChildElement('stringValue', SOAP_NS) != null) {
            targetValue = pmvValueElement.getChildElement('stringValue', SOAP_NS).getText();
        } else if (pmvValueElement.getChildElement('numberValue', SOAP_NS) != null){
            targetValue = pmvValueElement.getChildElement('numberValue', SOAP_NS).getText();
        } else throw new PBConvertException('tried to get a value from a node but could get the right type');

        System.debug('targetValue is: ' + targetValue);
        return targetValue;

    }

    public static List<Dom.XmlNode> getChildrenByName(Dom.XmlNode flowXml, String elementName) {
        System.debug ('getting children with the name: ' + elementName);
        List<Dom.XmlNode> allNodes = flowXml.getChildren();
        List<Dom.XMLNode> matchingNodes = new  List<Dom.XMLNode>();

        //look across all of the main Flow elements
        for (Dom.xmlNode curNode : allNodes) {
            if (curNode.getName() == elementName)
                   matchingNodes.add(curNode);
            

        }
        System.debug ('number of nodes matching target: ' + elementName + ' ' + matchingNodes.size());
        return matchingNodes;
    

    }
   
    public static Dom.XmlNode getChildNodeByInternalName(Dom.XmlNode flowXml, String target) {
        System.debug ('getting child node with the name: ' + target);
        List<Dom.XmlNode> allNodes = flowXml.getChildren();
        //look across all of the main Flow elements
        for (Dom.xmlNode curNode : allNodes) {
            //inspect the Name element of each element, if it exists
            for (Dom.XMLNode curNodeElement : curNode.getChildren()){
                if (curNodeElement.getName() == 'name')
                    if (curNodeElement.getText() == target)
                        return curNode;
            }

        }
        System.debug ('failed to find child node with the name ' + target);
        return null;
    }

    //look for a 'name' element in this node and return the name if you find it
    public static String getInternalName(Dom.XmlNode curNode) {
        if (curNode!= null){
            Dom.XmlNode curNameElement = curNode.getChildElement('name', SOAP_NS);
            if (curNameElement != null ) {
                return curNameElement.getText();
            }
            else return 'No Name Element found on this node';
        }
        else return 'attempted to get the name of a null node';
       
    }

    //this general search will return the specific node that has a child that matches the inputs
    //example:
    //given:
        /* <Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
                
            <rules>
                <fullName>wfr_acct1</fullName>

            </rules>
            <rules>
                <fullName>wfr_acct2</fullName>
            </rules>
        </Workflow> */

    // if you want to extract the rules entity with the fullName wfr_acct1, you would set:
    // indexEntityName = 'fullName';
    //entityTypeName = 'rules';
    //targetName 'wfr_acct1';


    public static Dom.XmlNode getChildNodeByName(Dom.XmlNode baseXML, String indexEntityName, String entityTypeName, String targetName) {
        for(Dom.XMLNode childElement : baseXML.getChildElements()) {
            if (childElement.getName() == entityTypeName) {
                for (Dom.XMLNode grandchildElement : childElement.getChildElements()){
                    //System.debug('the current child of the processmetadatavalue element is ' + pmvChild);
                    if (grandchildElement.getName() == indexEntityName) {
                       // System.debug ('this child is named name');
                        if (grandchildElement.getText() == targetName) {
                            System.debug ('theres a match between the value of this element and the passed in value: ' + targetName);
                            return childElement;
                        }
                    }
                }
            }
            
        }
        throw new PBConvertException('tried but failed to find a node with the name: '+ entityTypeName + 'that matched the criteria');
 
    }


    public static Dom.XmlNode getChildProcessMetadataValueByName(Dom.XmlNode flowXML, String pmvTargetName) {
        for(Dom.XMLNode pmv : flowXML.getChildElements()) {
           // System.debug('current child element of flow is: ' + pmv);
            if (pmv.getName() == 'processMetadataValues') {
                //System.debug ('this one has the name processMetadataValue'); 
                for (Dom.XMLNode pmvChild : pmv.getChildElements()){
                    //System.debug('the current child of the processmetadatavalue element is ' + pmvChild);
                    if (pmvChild.getName() == 'name') {
                       // System.debug ('this child is named name');
                        if (pmvChild.getText() == pmvTargetName) {
                            System.debug ('theres a match between the value of this element and the passed in value: ' + pmvTargetName);
                            return pmv;
                        }
                    }
                }
            }
            
        }
        throw new PBConvertException('tried  but failedto find a node with the name: '+ pmvTargetName);
 
    }

    public class PBConvertException extends Exception{}
}