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
@IsTest
public with sharing class CBPayrollExpressTest {

	@testSetup
	static void generateInitialData() {
		cb5__CBOrgVariable__c orgVariable = new cb5__CBOrgVariable__c(Name = 'General');
		insert orgVariable;

		cb5__CBBudgetYear__c budgetYear = new cb5__CBBudgetYear__c(Name = '2025', cb5__Start__c = Date.newInstance(2025, 1, 1));
		insert budgetYear;

		List<cb5__CBPeriod__c> periods = new List<cb5__CBPeriod__c>();
		for (Integer i = 0; i < 4; i++) periods.add(new cb5__CBPeriod__c(Name = 'Q' + 1, cb5__Start__c = Date.newInstance(2024, i + 1, 1), cb5__End__c = Date.newInstance(2024, i + 1, 25), cb5__CBBudgetYear__c = budgetYear.Id));
		insert periods;

		cb5__CBAccountType__c accType = new cb5__CBAccountType__c(Name = 'Expense', cb5__Sign__c = '+');
		insert accType;
		cb5__CBSubAccount__c accSubtype = new cb5__CBSubAccount__c(Name = 'Test');
		insert accSubtype;
		cb5__CBAccount__c acc = new cb5__CBAccount__c(Name = 'Test', cb5__CBAccountType__c = accType.Id, cb5__CBSubAccount__c = accSubtype.Id);
		insert acc;

		cb5__CBDivision__c division = new cb5__CBDivision__c(Name = 'Test');
		insert division;
		cb5__CBVariable5__c emp = new cb5__CBVariable5__c(Name = 'Martin');
		insert emp;

		List<cb5__CBLayer__c> layers = new List<cb5__CBLayer__c>();
		layers.add(new cb5__CBLayer__c(Name = 'Category'));
		layers.add(new cb5__CBLayer__c(Name = 'Tax'));
		insert layers;
		List<cb5__CBNonFinancialLibrary__c> libs = new List<cb5__CBNonFinancialLibrary__c>();
		libs.add(new cb5__CBNonFinancialLibrary__c(Name = 'Rate', cb5__Layer__c = layers[0].Id));
		libs.add(new cb5__CBNonFinancialLibrary__c(Name = 'Hours', cb5__Layer__c = layers[0].Id));
		libs.add(new cb5__CBNonFinancialLibrary__c(Name = 'Th1', cb5__SingleValue__c = 0.5, cb5p__From__c = 0, cb5p__UpTo__c = 1000, cb5__Layer__c = layers[1].Id, cb5__Type__c = 'Tax'));
		insert libs;

		cb5__CBNonFinancialLibrary__c parentLib = new cb5__CBNonFinancialLibrary__c(Name = 'Threshold Parent', cb5p__NFL1__c = libs[2].Id, cb5__Type__c = 'Tax', cb5__Layer__c = layers[1].Id);
		insert parentLib;

		CBCategory__c category = new CBCategory__c(
				Name = 'Salary',
				CBEmployee__c = emp.Id,
				Formula__c = '#1 * #2',
				CBAccount__c = acc.Id,
				CBDivision__c = division.Id,
				NFL1__c = libs[0].Id,
				NFL2__c = libs[1].Id,
				TaxThreshold__c = parentLib.Id,
				Value__c = 0,
				Index__c = 1,
				CBBudgetYear__c = budgetYear.Id
		);
		insert category;
	}

	@IsTest
	static void testPayrollExpressPageController() {
		cb5__CBBudgetYear__c budgetYear = [SELECT Id FROM cb5__CBBudgetYear__c];
		CBCategory__c category = [SELECT Id FROM CBCategory__c];
		cb5__CBVariable5__c employee = [SELECT Id FROM cb5__CBVariable5__c];
		cb5__CBNonFinancialLibrary__c lib = [SELECT Id, cb5__SingleValue__c, cb5p__From__c, cb5p__UpTo__c FROM cb5__CBNonFinancialLibrary__c LIMIT 1][0];
		Map<String, String> params = new Map<String, String>{
				'budgetYearId' => budgetYear.Id
		};
		List<cb5__CBVariable5__c> employees = CBPayrollExpressPageController.getEmployeesServer(params);
		params.put('employeeId', employee.Id);
		List<CBCategory__c> categories = CBPayrollExpressPageController.getCategoriesServer(params);
		CBPayrollExpressPageController.getNFLServer(new List<String>{
				lib.Id
		}, budgetYear.Id);
		Map<String, Map<String, String>> analytics = CBPayrollExpressPageController.getAnalyticsServer();
		CBPayrollExpressPageController.saveEmployeeServer(employee, budgetYear.Id);
		CBPayrollExpressPageController.saveCategoryServer(category, null);
		CBPayrollExpressPageController.categoryCanBeDeletedSafelyServer(category.Id);
		CBPayrollExpressPageController.getRecentNFLsServer(employee.Id);
		CBPayrollExpressPageController.getTaxThresholdsServer();
		CBPayrollExpressPageController.saveNFLibraryServer(lib);
		CBPayrollExpressPageController.addTaxThresholdServer();
		CBPayrollExpressPageController.deleteCategoryServer(category.Id);
	}

	@IsTest
	static void testTaxThresholdProcessor() {


	}


}