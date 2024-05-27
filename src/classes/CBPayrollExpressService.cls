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
public with sharing class CBPayrollExpressService {

	public static void deleteUnusedNFLLibrariesServer() {
		Set<String> usedNFL = new Set<String>();
		for (cb5__CBBudgetLine__c bl : [SELECT cb5__NFL1__c,cb5__NFL2__c,cb5__NFL3__c,cb5__NFL4__c,cb5__NFL5__c FROM cb5__CBBudgetLine__c]) {
			usedNFL.add(bl.cb5__NFL1__c);
			usedNFL.add(bl.cb5__NFL2__c);
			usedNFL.add(bl.cb5__NFL3__c);
			usedNFL.add(bl.cb5__NFL4__c);
			usedNFL.add(bl.cb5__NFL5__c);
		}
		for (CBCategory__c cat : [SELECT NFL1__c,NFL2__c,NFL3__c,NFL4__c,NFL5__c,NFLResult__c,TaxThreshold__c FROM CBCategory__c]) {
			usedNFL.add(cat.NFL1__c);
			usedNFL.add(cat.NFL2__c);
			usedNFL.add(cat.NFL3__c);
			usedNFL.add(cat.NFL4__c);
			usedNFL.add(cat.NFL5__c);
			usedNFL.add(cat.NFLResult__c);
			usedNFL.add(cat.TaxThreshold__c);
		}
		for (cb5__CBNonFinancialLibrary__c lib : [SELECT Id FROM cb5__CBNonFinancialLibrary__c WHERE cb5__Type__c = 'Tax' OR cb5__LayerTitle__c LIKE '%Tax%']) {
			usedNFL.add(lib.Id);
		}
		delete [SELECT Id FROM cb5__CBNonFinancialLibrary__c WHERE Id NOT IN :usedNFL];
	}

}