/** 
Copyright (c) 04 2024, AJR, CloudBudget, Inc.
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


public with sharing class CBCategoryProcessor {

	private static String budgetYearId;
	private static String employeeId;
	private static Set<String> budgetLineIdsToDelete = new Set<String>();
	private static List<BudgetLineWrapper> budgetLineWrappersToInsert = new List<BudgetLineWrapper>();
	private static List<CBCategory__c> categoriesToUpdate = new List<CBCategory__c>();
	private static List<cb5__CBPeriod__c> periods {
		get {
			if (periods == null) periods = [SELECT Id FROM cb5__CBPeriod__c WHERE cb5__CBBudgetYear__c = :budgetYearId ORDER BY cb5__Start__c];
			return periods;
		}
		set;
	}
	private static cb5__CBVariable5__c employee {
		get {
			if (employee == null) employee = CBEmployeeSelector.getEmployees(new Map<String, String>{
					'employeeId' => employeeId,
					'budgetYearId' => budgetYearId
			})[0];
			return employee;
		}
		set;
	}

	public static void updateEmployeeCategories(String empId, String byId) {
		budgetYearId = byId;
		employeeId = empId;
		Map<String, String> params = new Map<String, String>{
				'budgetYearId' => byId,
				'employeeId' => empId
		};
		for (CBCategory__c category : CBCategorySelector.getCategories(params)) {
			System.debug('IN PROGRESS:' + category.Name);
			List<cb5__CBAmount__c> calculatedAmounts = updateBudgetLineAndReturnCalculatedAmounts(category);
			updateCategoryResult(category, calculatedAmounts);
		}
		finalizeDLS();
	}

	private static void updateCategoryResult(CBCategory__c category, List<cb5__CBAmount__c> calculatedAmounts) {
		cb5__CBNonFinancialLibrary__c resultNFL = CBPayrollExpressPageController.getNFLServer(new List<String>{
				category.NFLResult__c
		}, budgetYearId) [0];
		category.Value__c = 0;
		for (Integer i = 0; i < calculatedAmounts.size(); i++) {
			resultNFL.cb5__NonFinancialItems__r[i].cb5__Value__c = calculatedAmounts[i].cb5__Value__c;
			category.Value__c += calculatedAmounts[i].cb5__Value__c;
		}
		update resultNFL.cb5__NonFinancialItems__r;
		categoriesToUpdate.add(category);
	}

	private static List<cb5__CBAmount__c> updateBudgetLineAndReturnCalculatedAmounts(CBCategory__c category) {
		budgetLineIdsToDelete.add(category.Id);

		BudgetLineWrapper blw = new BudgetLineWrapper();
		budgetLineWrappersToInsert.add(blw);
		cb5__CBBudgetLine__c bl = new cb5__CBBudgetLine__c(cb5__CBBudgetYear__c = budgetYearId);
		bl.cb5__CBDivision__c = category.CBDivision__c != null ? category.CBDivision__c : employee.CBDivision__c;
		bl.Name = (employee.Name + ' (' + category.Name + ')').left(80);
		bl.cb5__CBVariable5__c = employeeId;
		bl.cb5__Lock__c = 'Editing';
		bl.CBCategory__c = category.Id;
		bl.cb5__CBAccount__c = category.CBAccount__c;
		bl.cb5__DrillDownIds__c = category.Id;
		blw.budgetLine = bl;

		List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
		for (cb5__CBPeriod__c period : periods) amounts.add(new cb5__CBAmount__c(cb5__Value__c = 0, cb5__CBPeriod__c = period.Id));
		List<String> nflIds = new List<String>();
		if (category.NFL1__c != null) nflIds.add(category.NFL1__c);
		if (category.NFL2__c != null) nflIds.add(category.NFL2__c);
		if (category.NFL3__c != null) nflIds.add(category.NFL3__c);
		if (category.NFL4__c != null) nflIds.add(category.NFL4__c);
		if (category.NFL5__c != null) nflIds.add(category.NFL5__c);
		List<List<cb5__CBNonFinancialItem__c>> sourceLines = new List<List<cb5__CBNonFinancialItem__c>>();
		List<cb5__CBNonFinancialLibrary__c> libraries = CBPayrollExpressPageController.getNFLServer(nflIds, budgetYearId);
		List<cb5__CBNonFinancialLibrary__c> sortedLibraries = new List<cb5__CBNonFinancialLibrary__c>();
		for (String nflID : nflIds) {
			for (cb5__CBNonFinancialLibrary__c nfl : libraries) if (nfl.Id == nflID) sortedLibraries.add(nfl);
		}
		for (cb5__CBNonFinancialLibrary__c nfl : sortedLibraries) sourceLines.add(nfl.cb5__NonFinancialItems__r);
		blw.amounts = cb5.CBFormulaService.calculateFormulaTotals(amounts, sourceLines, category.Formula__c);
		return blw.amounts;
	}

	private static void finalizeDLS() {
		delete [SELECT Id FROM cb5__CBBudgetLine__c WHERE CBCategory__c IN:budgetLineIdsToDelete];
		new BudgetLineWrapper().insertBudgetLineWrappers(budgetLineWrappersToInsert);
		update categoriesToUpdate;
	}

	/**
	 * Wrapper for budget lines and amounts
	 */
	public class BudgetLineWrapper {
		cb5__CBBudgetLine__c budgetLine;
		List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
		public void insertBudgetLineWrappers(List<BudgetLineWrapper> budgetLineWrappers) {
			List<cb5__CBBudgetLine__c> budgetLines = new List<cb5__CBBudgetLine__c>();
			List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
			for (BudgetLineWrapper blw : budgetLineWrappers) {
				budgetLines.add(blw.budgetLine);
				amounts.addAll(blw.amounts);
			}
			insert budgetLines;
			for (BudgetLineWrapper blw : budgetLineWrappers)
				for (cb5__CBAmount__c a : blw.amounts) a.cb5__CBBudgetLine__c = blw.budgetLine.Id;
			insert amounts;
		}
	}


}