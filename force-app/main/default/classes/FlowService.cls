public with sharing class FlowService {


public static MetadataService.Flow createFlowInMemory(String flowName) {
	// Create Flow
	MetadataService.Flow flow = new MetadataService.Flow();
	flow.fullName = flowName + '-1';
	flow.description = flowName;
	flow.label = flowName;
	flow.processType = 'Flow';
	return flow;
}


public static void setStartingNode(MetadataService.Flow flow, String nodeName){
	flow.startElementReference = nodeName;
}

public static void saveFlow(MetadataService.MetadataPort service, MetadataService.Flow flow){
	handleSaveResults(service.createMetadata(new List<MetadataService.Metadata> { flow })[0]);
}


public static void addSubflowInputAssignmentValue(MetadataService.FlowSubflow subflow, string inputName, String value)
{
	MetadataService.FlowSubflowInputAssignment inputVar = addSubflowInputAssignment(subflow, inputName);
	inputVar.value = valueToReference(value);
}

public static void addSubflowInputAssignmentValue(MetadataService.FlowSubflow subflow, string inputName, Boolean value)
{
	MetadataService.FlowSubflowInputAssignment inputVar = addSubflowInputAssignment(subflow, inputName);
	inputVar.value = valueToReference(value);
}

private static MetadataService.FlowSubflowInputAssignment addSubflowInputAssignment(MetadataService.FlowSubflow subflow, string inputName){
	if (subflow.inputAssignments==null)
		subflow.inputAssignments = new List<MetadataService.FlowSubflowInputAssignment>();

	MetadataService.FlowSubflowInputAssignment inputVar = new MetadataService.FlowSubflowInputAssignment();
	inputVar.name = inputName;
	subflow.inputAssignments.add(inputVar);
	return inputVar;
}

private static MetadataService.FlowElementReferenceOrValue valueToReference(Boolean value){
	MetadataService.FlowElementReferenceOrValue reference = new MetadataService.FlowElementReferenceOrValue();
	reference.booleanValue = value;
	return reference;
}

private static MetadataService.FlowElementReferenceOrValue valueToReference(String value){
	MetadataService.FlowElementReferenceOrValue reference = new MetadataService.FlowElementReferenceOrValue();
	reference.stringValue = value;
	return reference;
}

public static void handleSaveResults(MetadataService.SaveResult saveResult)
{
	// Nothing to see?
	if(saveResult==null || saveResult.success)
		return;
	// Construct error message and throw an exception
	if(saveResult.errors!=null)
	{
		List<String> messages = new List<String>();
		messages.add(
			(saveResult.errors.size()==1 ? 'Error ' : 'Errors ') +
			'occured processing component ' + saveResult.fullName + '.');
		for(MetadataService.Error error : saveResult.errors)
			messages.add(
				error.message + ' (' + error.statusCode + ').' +
				( error.fields!=null && error.fields.size()>0 ?
				  ' Fields ' + String.join(error.fields, ',') + '.' : '' ) );
		if(messages.size()>0)
			throw new FlowServiceException(String.join(messages, ' '));
	}
	if(!saveResult.success)
		throw new FlowServiceException('Request failed with no specified error.');
}
public class FlowServiceException extends Exception {}

}
