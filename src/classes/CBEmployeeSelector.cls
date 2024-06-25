/** 
Copyright (c) 2024, CloudBudget, Inc.
All rights reserved.
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.
* Neither the name of the CloudBudget, Inc. nor the names of its contributors
may be used to endorse or promote products derived from this software
without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
OF THE POSSIBILITY OF SUCH DAMAGE.
 */
public with sharing class CBEmployeeSelector {

	/**
	 * @param params - page params
	 *
	 * @return list of variable5 (employees)
	 */
	public static List<cb5__CBVariable5__c> getEmployees(Map<String, String> params) {
		String byId = params.get('budgetYearId');
		String divisionId = params.get('divisionId');
		String employeeId = params.get('employeeId');
		String s = 'SELECT Id,Name,CBDivision__c,CBDivision__r.Name,Position__c,SIC__c, ' +
				'(SELECT Id,Name,Type__c,Value__c FROM CBCategories__r WHERE CBBudgetYear__c = \'' + byId + '\' ORDER BY Index__c) ';
		String f = ' FROM  cb5__CBVariable5__c ';
		String w = ' WHERE Name != null '; // CBBudgetYear__c = \'' + byId + '\'
		if (divisionId != null && divisionId.length() > 10) w += ' AND CBDivision__c = \'' + divisionId + '\' ';
		if (employeeId != null && employeeId.length() > 10) w += ' AND Id = \'' + employeeId + '\' ';
		String o = ' ORDER BY Name ';
		return Database.query(s + f + w + o);
	}

}