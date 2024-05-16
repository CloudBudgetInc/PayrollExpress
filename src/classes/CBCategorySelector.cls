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
public with sharing class CBCategorySelector {

	public static List<CBCategory__c> getCategories(Map<String, String> params) {
		String byId = params.get('budgetYearId');
		String divisionId = params.get('divisionId');
		String employeeId = params.get('employeeId');
		String categoryId = params.get('categoryId');
		String s = 'SELECT Id,Name,Type__c,CBEmployee__c,Formula__c,CBAccount__c,CBDivision__c,NFLResult__c,NFL1__c,NFL2__c,NFL3__c,NFL4__c,NFL5__c,' +
				'ParentCategory__c,Value__c,Index__c,CBBudgetYear__c,Allocation__c,isAllocated__c,TaxThreshold__c ';
		String f = ' FROM CBCategory__c ';
		String w = ' WHERE CBEmployee__c != null ';
		if (byId != null) w += ' AND CBBudgetYear__c = \'' + byId + '\' ';
		if (categoryId != null) w += ' AND Id = \'' + categoryId + '\' ';
		if (divisionId != null) w += ' AND CBDivision__c = \'' + divisionId + '\' ';
		if (employeeId != null) w += ' AND CBEmployee__c = \'' + employeeId + '\' ';
		String o = ' ORDER BY Index__c ';
		return Database.query(s + f + w + o);
	}

	public static List<CBCategory__c> getCategories2(Map<String, String> params) {
		String byId = params.get('budgetYearId');
		String divisionId = params.get('divisionId');
		String employeeId = params.get('employeeId');
		String categoryId = params.get('categoryId');
		String s = 'SELECT Id,Name,Type__c,Formula__c,CBAccount__c,CBDivision__c,NFLResult__c,NFL1__c,NFL2__c,NFL3__c,NFL4__c,NFL5__c,ParentCategory__c,Value__c,Index__c,CBBudgetYear__c,Allocation__c ';
		String f = ' FROM CBCategory__c ';
		String w = ' WHERE CBEmployee__c != null ';
		if (byId != null) w += ' AND CBBudgetYear__c = \'' + byId + '\' ';
		if (categoryId != null) w += ' AND Id = \'' + categoryId + '\' ';
		if (divisionId != null) w += ' AND CBDivision__c = \'' + divisionId + '\' ';
		if (employeeId != null) w += ' AND CBEmployee__c = \'' + employeeId + '\' ';
		String o = ' ORDER BY Index__c ';
		return Database.query(s + f + w + o);
	}

}