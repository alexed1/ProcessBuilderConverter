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

   /*  Given a set of nodes like this:
    <processMetadataValues>
        <name>OldObjectVariable</name>
        <value>
            <elementReference>myVariable_old</elementReference>
        </value>
    </processMetadataValues> 
    you would delete this node by passing in targetNodeElementName of processMetadataValues and targetNodeNameValue of OldObjectVariable
    the node must have a name element */
    public static void deleteNode(List<Dom.XmlNode> curNodes, String targetNodeElementName, String targetNodeNameValue ) {
        List<Dom.XmlNode> candidateNodes = new List<Dom.XmlNode>();
        for ( Dom.XmlNode curNode : curNodes) {
            if(curNode.getName() == targetNodeElementName){
                candidateNodes.add(curNode);
            }
        }
        for (Dom.XmlNode curNode : candidateNodes) {
            if (curNode.getChildElement('name', SOAP_NS).getText() == targetNodeNameValue)
                deleteSelf(curNode);
        }


    }

    public static List<Dom.XmlNode> getChildrenByName(Dom.XmlNode flowXML, String targetName) {
        List<Dom.XmlNode> matchingNodes = new List<Dom.XmlNode>();
        List<Dom.XmlNode> allNodes = flowXML.getChildren();
        for (Dom.XmlNode curNode : allNodes) {
            if (curNode.getName() == targetName)
                matchingNodes.add(curNode);
        }
        return matchingNodes;
    } 
   
    public static void removeExcessPMV(Dom.XmlNode flowXML, String pmvName) {
        deleteNode(flowXML.getChildren(), 'processMetadataValues', pmvName);
    
    }

    public static Dom.XmlNode setTriggerType(Dom.XmlNode flowXML, Boolean isWorkflow){
        Dom.XmlNode startElement = flowXML.getChildElement('start', SOAP_NS);
        List<Dom.XmlNode> schedulePathList = XmlUtils.getChildrenByName(startElement, 'scheduledPaths');
        String triggerType = 'RecordBeforeSave';
        if(schedulePathList.size() > 0) {
            triggerType = 'RecordAfterSave';
        }

        List<Dom.XmlNode> actionList = XmlUtils.getChildrenByName(flowXml, 'actionCalls');

        if(actionList.size() > 0 ) {
            triggerType = 'RecordAfterSave';
        }

        List<Dom.XmlNode> recordLookupsList = XmlUtils.getChildrenByName(flowXml, 'recordLookups');

        if(recordLookupsList.size() > 0 ) {
            triggerType = 'RecordAfterSave';
        }

        List<Dom.XmlNode> recordCreatesList = XmlUtils.getChildrenByName(flowXml, 'recordCreates');

        if(recordCreatesList.size() > 0 ) {
            triggerType = 'RecordAfterSave';
        }

        List<Dom.XmlNode> recordDeletesList = XmlUtils.getChildrenByName(flowXml, 'recordDeletes');

        if(recordDeletesList.size() > 0 ) {
            triggerType = 'RecordAfterSave';
        }

        List<Dom.XmlNode> subflowsList = XmlUtils.getChildrenByName(flowXml, 'subflows');

        if(subflowsList.size() > 0 ) {
            triggerType = 'RecordAfterSave';
        }

        List<Dom.XmlNode> recordUpdatesList = XmlUtils.getChildrenByName(flowXml, 'recordUpdates');
        for(Dom.XmlNode recordUpdates : recordUpdatesList) {
            List<dom.XmlNode> filters = XmlUtils.getChildrenByName(recordUpdates, 'filters');

            if(filters.size() > 1 || filters.size() == 0) {
                triggerType = 'RecordAfterSave';
            } else if(filters.size() == 1) {
                String field = filters[0].getChildElement('field', SOAP_NS).getText();
                String operator = filters[0].getChildElement('operator', SOAP_NS).getText();
                Dom.XmlNode value =  filters[0].getChildElement('value', SOAP_NS);
                Dom.XmlNode elementReference;
                if(value != null) {
                    elementReference =  value.getChildElement('elementReference', SOAP_NS);
                }

                if(field != 'Id' || operator != 'EqualTo' || value == null || elementReference == null || (elementReference.getText() != 'myVariable_current.Id' && elementReference.getText() != '$Record.Id')) {
                    triggerType = 'RecordAfterSave';
                } else {
                    recordUpdates.removeChild(filters[0]);
                    recordUpdates.addChildElement('inputReference', SOAP_NS, null).addTextNode('$Record');
                    Dom.XmlNode objectXML  =  recordUpdates.getChildElement('object', SOAP_NS);
                    recordUpdates.removeChild(objectXML);
                }

            } 
        }
        
        startElement.addChildElement('triggerType', SOAP_NS, null).addTextNode(triggerType);
        
        return null;
    }

    public static void repositionElements(Dom.Document doc) {
        //get Decision elements that have order values into a group

        //get first decision element and verify that it has index 0
      
        Dom.XmlNode flowXml = doc.getRootElement();
        List<Dom.XmlNode> curDecisionNodes =  getChildrenByName(flowXML,'decisions');
        //System.debug('curDecisionNodes is: ' + curDecisionNodes);
        String curIndexVal = '0.0';
        //it appears to be safe to assume that the first decision node returned is always the first node in pb. we can verify by looking for index
        Dom.XmlNode curDecisionNode = curDecisionNodes[0];
        //verify index  
        Dom.XmlNode indexNode = XmlUtils.getChildProcessMetadataValueByName(curDecisionNode, 'index');
        String retrievedIndexVal = XmlUtils.getProcessMetadataValue(indexNode);
        System.debug ('indexNode is ' + retrievedIndexVal);
        System.debug ('targetindexval is ' + curIndexVal);
        if (retrievedIndexVal != curIndexVal)
            throw new PBConvertException('expected a different index value of the current decision node:' + curDecisionNode);
         // set its Y Pos to 300 + order*100
        //System.debug('beforexypos, state is: ' + doc.toXmlString());
        setXYPosition(curDecisionNode, '43', '300');
       // System.debug('afterxypos, state is: ' + doc.toXmlString());
        Boolean finished = false;
        Integer yPosition = 300;
        while(finished != true) {
            repositionActions(doc, curDecisionNode, String.valueOf(yPosition));
            yPosition = yPosition + 200;
            Dom.XmlNode defaultConnectorElement = curDecisionNode.getChildElement('defaultConnector', SOAP_NS);
            if (defaultConnectorElement != null ) {
                String nextDefaultNodeName = defaultConnectorElement.getChildElement('targetReference', SOAP_NS).getText();
                if (nextDefaultNodeName != null) {
                    for (Dom.XmlNode nextDecisionCandidate : curDecisionNodes ) {
                        if (nextDecisionCandidate.getChildElement('name', SOAP_NS).getText() == nextDefaultNodeName) {
                            setXYPosition(nextDecisionCandidate, '43', String.valueOf(yPosition) );
                            System.debug ('setting position of: ' + nextDefaultNodeName + 'to a Y position of: ' + yPosition);
                            curDecisionNode = nextDecisionCandidate;
                        }
                    }
                }else throw new PBConvertException('something went wrong. found a default connector in a decision element but didnt find a name value inside');
                
            } else {
                finished = true;
            }
            
            
        }

    }

    public static String getTargetReference(Dom.XmlNode curNode) {
        Dom.XmlNode nodeConnectorElement = curNode.getChildElement('connector', SOAP_NS);
        if (nodeConnectorElement != null ) {
            String nodeConnectorTargetReferenceElementText = nodeConnectorElement.getChildElement('targetReference', SOAP_NS).getText();
            if (nodeConnectorTargetReferenceElementText != null) {
                return nodeConnectorTargetReferenceElementText;
            }

        }
        System.debug('failed to find next node name for this node: ' + XmlUtils.getInternalName(curNode));
        return null;
    }



    //finds the targetReference value
    public static String findNextNodeName(Dom.XmlNode curNode) {
        System.debug('finding next node name forthis node: ' + XmlUtils.getInternalName(curNode));
        //if the curNode name is decisions do rules than connnector, else just connector 
         
        if (curNode.getName() == 'decisions'){
            Dom.XmlNode nodeRulesElement = curNode.getChildElement('rules', SOAP_NS);
            if (nodeRulesElement != null ) {
               return getTargetReference(nodeRulesElement);
            }
            System.debug('failed to find next node name for this node: ' + XmlUtils.getInternalName(curNode));
        } else {
            return getTargetReference(curNode);
        }
        return null;

    }

    public static void repositionActions(Dom.Document doc, Dom.XmlNode coreDecisionNode, String currentYPos) {
        System.debug('entering repositionActions');
        Dom.XmlNode flowXml = doc.getRootElement();
        Integer xPosition = 400;
        String nextNodeName= findNextNodeName(coreDecisionNode);
        while (nextNodeName != null && !nextNodeName.contains('decision')) {
            System.debug ('nextNodeName is: ' + nextNodeName);
            //find child of flowxml that has a child name element equal to this  generalize getChildProcessMetadataValueByName
            Dom.XmlNode targetNode = XmlUtils.getChildNodeByInternalName(flowXML, nextNodeName);
            
            setXYPosition(targetNode,String.valueOf(xPosition), currentYPos);
            xPosition = xPosition + 150;
            
            //look in the node for another connector. if you find one, set nextNodeName equal to the new value, else set nextNodeName to null
            nextNodeName = findNextNodeName(targetNode);
        } 

    }

    public static void setXYPosition(Dom.XmlNode curNode, String newXVal, String newYVal) {
        System.debug('changing the position of this node: ' + XmlUtils.getInternalName(curNode) + ' to xval ' + newXVal + ' and to yval ' + newYVal);
        Dom.XmlNode curXPos = curNode.getChildElement('locationX', SOAP_NS);
        Dom.XmlNode curYPos = curNode.getChildElement('locationY', SOAP_NS);
         if (curXPos == null || curYPos == null)
             throw new PBConvertException('tried to set the x or y position on an xml node that does not support position values');
        deleteSelf(curXPos);
        curNode.addChildElement('locationX', SOAP_NS, null).addTextNode(newXVal);
        deleteSelf(curYPos);
        curNode.addChildElement('locationY', SOAP_NS, null).addTextNode(newYVal);

    }

   

    //delete the variable myVariable_current
    //change all existing myVariable_current references to $Record
    public static Dom.Document changeContextReference(Dom.Document doc) {
        
        Dom.XMLNode flowXML = doc.getRootElement();

        List<Dom.XmlNode> allNodes = flowXML.getChildren();
        deleteNode(allNodes, 'variables', 'myVariable_current');
        
        //find and replace
         String metadataString = doc.toXmlString();
        metadataString = metadataString.replace('myVariable_current', '$Record');
        metadataString = metadataString.replace('{!$', '{! $');
        //System.debug('metadatastring is: ' + metadataString);
        Dom.Document convertedDoc = new Dom.Document();
        convertedDoc.load(metadataString);   
        return convertedDoc; 

    }

    public static Dom.Document fixupRelatedReferences(Dom.Document doc) {
        
        //find and replace
        String metadataString = doc.toXmlString();
        metadataString = metadataString.replace('Owner.Id', 'OwnerId');
        metadataString = metadataString.replace('User.Id', 'UserId');
        Dom.Document convertedDoc = new Dom.Document();
        convertedDoc.load(metadataString);
        return convertedDoc;
        
    }

    public static Dom.XmlNode addStartElement(Dom.XmlNode flowXML, String contextObjectType, String triggerType, String startElementReference, List<ConvertFlowMetadata.WaitElementsWrapper> elements) {
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
        startNode.addChildElement('recordTriggerType', SOAP_NS, null).addTextNode(
            String.isEmpty(triggerType) ? 'Create' : triggerType == 'onAllChanges' ? 'CreateAndUpdate' : 'Create'
            );

        Integer scheduleCount = 1;

        for(ConvertFlowMetadata.WaitElementsWrapper waitElements: elements){
            Dom.XmlNode scheduledNode = startNode.addChildElement('scheduledPaths', SOAP_NS, null);
            scheduledNode.addChildElement('name', SOAP_NS,null).addTextNode('Scheduled_Path_' + scheduleCount);
            scheduledNode.addChildElement('connector', SOAP_NS, null).addChildElement('targetReference', SOAP_NS, null).addTextNode(waitElements.connector);
            scheduledNode.addChildElement('label', SOAP_NS, null).addTextNode('Scheduled Path ' + scheduleCount);
            scheduledNode.addChildElement('offsetNumber', SOAP_NS, null).addTextNode(waitElements.offsetNumber);
            scheduledNode.addChildElement('offsetUnit', SOAP_NS, null).addTextNode(waitElements.offsetUnit);

            scheduleCount++;

            if(waitElements.recordField!= null) {
                scheduledNode.addChildElement('recordField', SOAP_NS, null).addTextNode(waitElements.recordField);
            } else {
                scheduledNode.addChildElement('recordField', SOAP_NS, null).addTextNode('LastModifiedDate');
            }
            scheduledNode.addChildElement('timeSource', SOAP_NS, null).addTextNode('RecordField');

        }
        //startNode.addChildElement('triggerType', SOAP_NS, null).addTextNode('RecordAfterSave');
        


        //System.debug ('flowxml with start is: ' + flowXML);
        
        return flowXML;

        
    }

    public static void sortXMLChildren(Dom.XmlNode flowXML, Dom.XmlNode node, String nodeName) {
        
        List<Dom.XmlNode> childList = XmlUtils.getChildrenByName(flowXml, nodeName);
        if(childList.size() > 1) {
            node.getParent().removeChild(node);
            childList = XmlUtils.getChildrenByName(flowXml, nodeName);
            if(childList != null && childList.size() > 0) {
                node = flowXML.insertBefore(node, childList[0]);
            }
        }      

    }

    public static void convertSubflow(Dom.XmlNode flowXML) {
        List<Dom.XmlNode> actionCallList = XmlUtils.getChildrenByName(flowXML, 'actionCalls');

        for(Dom.XmlNode actionCall : actionCallList) {
            Dom.XmlNode actionType = actionCall.getChildElement('actionType', SOAP_NS);
            if(actionType != null && actionType.getText() == 'flow') {
                String name = actionCall.getChildElement('name', SOAP_NS).getText();
                string label = actionCall.getChildElement('label', SOAP_NS).getText();
                String flowName = actionCall.getChildElement('actionName', SOAP_NS).getText();
                String targetReference = '';
                Dom.XmlNode connector = actionCall.getChildElement('connector', SOAP_NS);
                if(connector != null) {
                    targetReference = connector.getChildElement('targetReference', SOAP_NS).getText();
                }

                Dom.XmlNode subflow = flowXML.addChildElement('subflows', SOAP_NS, null);
                subflow.addChildElement('name', SOAP_NS, null).addTextNode(name);
                subflow.addChildElement('label', SOAP_NS, null).addTextNode(label);
                subflow.addChildElement('flowName', SOAP_NS, null).addTextNode(flowName);
                subflow.addChildElement('storeOutputAutomatically', SOAP_NS, null).addTextNode('true');
                subflow.addChildElement('locationX', SOAP_NS, null).addTextNode('100');
                subflow.addChildElement('locationY', SOAP_NS, null).addTextNode('300');
                if(String.isNotEmpty(targetReference)) {
                    subflow.addChildElement('connector', SOAP_NS, null).addChildElement('targetReference', SOAP_NS, null).addTextNode(targetReference);
                }

                List<Dom.XmlNode> inputList = XmlUtils.getChildrenByName(actionCall, 'inputParameters');
                for(Dom.XmlNode input : inputList) {
                    String inputName = input.getChildElement('name', SOAP_NS).getText();
                    Dom.XmlNode inputAssignment = subflow.addChildElement('inputAssignments', SOAP_NS, null);
                    inputAssignment.addChildElement('name', SOAP_NS, null).addTextNode(inputName);
                    Dom.XmlNode value = input.getChildElement('value', SOAP_NS);
                    List<Dom.XmlNode> typesList = value.getChildElements();
                    for(Dom.XmlNode type : typesList) {
                        System.debug('types ' + type.getName() );
                        inputAssignment.addChildElement('value', SOAP_NS, null).addChildElement(type.getName(), SOAP_NS, null).addTextNode(type.getText());
                    }

                }

                actionCall.getParent().removeChild(actionCall);
            }
        } 
    }

    public class PBConvertException extends Exception{}

}