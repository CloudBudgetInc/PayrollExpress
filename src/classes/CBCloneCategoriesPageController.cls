/** 
Copyright (c) 2024, AJR, CloudBudget, Inc.
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


public with sharing class CBCloneCategoriesPageController {

	private static String employeeId;
	private static String sourceBudgetYearId;
	private static String targetBudgetYearId;

	@AuraEnabled
	public static void cloneCategoriesToTargetBudgetYearServer(String empId, String sourceBYId, String targetBYId) {
		employeeId = empId;
		sourceBudgetYearId = sourceBYId;
		targetBudgetYearId = targetBYId;
		deleteOldCategories();
		cloneCategories();
	}

	private static void deleteOldCategories() {
		delete [SELECT Id FROM CBCategory__c WHERE CBEmployee__c = :employeeId AND CBBudgetYear__c = :targetBudgetYearId LIMIT 50000];
	}

	private static void cloneCategories() {
		Map<String, String> params = new Map<String, String>{
				'employeeId' => employeeId,
				'budgetYearId' => sourceBudgetYearId
		};
		List<CBCategory__c> sourceCategories = CBCategorySelector.getCategories(params);
		List<CBCategory__c> targetCategories = new List<CBCategory__c>();
		for (CBCategory__c cat : sourceCategories) {
			CBCategory__c targetCategory = cat.clone(false, true, false, false);
			targetCategory.CBBudgetYear__c = targetBudgetYearId;
			targetCategories.add(targetCategory);
		}
		insert targetCategories;
	}

}