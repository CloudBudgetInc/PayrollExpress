import {_message} from "c/cbUtils";

const validateCategory = (category) => {
	let messageList = [];
	if (!category.Name) messageList.push('Set some name to the category');
	if (!category.cb5p__Type__c) messageList.push('Set some type to the category');
	if (!category.cb5p__CBAccount__c) messageList.push('Set some account to the category');

	messageList.forEach(message => _message('warning', message));
	return messageList.length > 0;
};

export {validateCategory};