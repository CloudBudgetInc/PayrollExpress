/** 
Copyright (c) 04 2024, Alex JR, CloudBudget, Inc.
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
public with sharing class CBTaxThresholdProcessor {

	/**
	 * Map of tax thresholds. Key is parent threshold NFL Id, value - list of its children
	 */
	private static Map<String, List<cb5__CBNonFinancialLibrary__c>> thresholdMap {
		get {
			if (thresholdMap == null) {
				thresholdMap = new Map<String, List<cb5__CBNonFinancialLibrary__c>>();
				Set<String> thresholdIds = new Set<String>();
				List<cb5__CBNonFinancialLibrary__c> thrParents = [SELECT NFL1__c,NFL2__c,NFL3__c,NFL4__c,NFL5__c FROM cb5__CBNonFinancialLibrary__c WHERE cb5__Type__c = 'Tax'];
				for (cb5__CBNonFinancialLibrary__c thrParent : thrParents) {
					thresholdIds.add(thrParent.NFL1__c);
					thresholdIds.add(thrParent.NFL2__c);
					thresholdIds.add(thrParent.NFL3__c);
					thresholdIds.add(thrParent.NFL4__c);
					thresholdIds.add(thrParent.NFL5__c);
				}
				Map<String, cb5__CBNonFinancialLibrary__c> internalMap = new Map<String, cb5__CBNonFinancialLibrary__c>();
				for (cb5__CBNonFinancialLibrary__c thr : [
						SELECT cb5p__From__c,cb5p__UpTo__c,cb5__SingleValue__c, (SELECT cb5__CBPeriod__c,cb5__Value__c FROM cb5__NonFinancialItems__r)
						FROM cb5__CBNonFinancialLibrary__c
						WHERE Id IN:thresholdIds
				]) internalMap.put(thr.Id, thr);
				for (cb5__CBNonFinancialLibrary__c p : thrParents) {
					List<cb5__CBNonFinancialLibrary__c> childList = new List<cb5__CBNonFinancialLibrary__c>();
					if (p.NFL1__c != null) childList.add(internalMap.get(p.NFL1__c));
					if (p.NFL2__c != null) childList.add(internalMap.get(p.NFL2__c));
					if (p.NFL3__c != null) childList.add(internalMap.get(p.NFL3__c));
					if (p.NFL4__c != null) childList.add(internalMap.get(p.NFL4__c));
					if (p.NFL5__c != null) childList.add(internalMap.get(p.NFL5__c));
					thresholdMap.put(p.Id, childList);
				}
			}
			return thresholdMap;
		}
		set;
	}
	/**
	 *
	 * @param blw budget line wrapper
	 * @param ttId Threshold parent nfl id
	 */
	public static void applyTaxThresholds(List<cb5__CBNonFinancialItem__c> items, String ttId) {
		try {
			List<cb5__CBNonFinancialLibrary__c> thresholds = thresholdMap.get(ttId);
			Decimal yearlyTotal = 0;
			for (cb5__CBNonFinancialItem__c item : items) yearlyTotal += item.cb5__Value__c; // budget line yearly value
			Decimal yearlyTax = 0; // total tax for whole budget year
			for (cb5__CBNonFinancialLibrary__c thr : thresholds) {
				if (yearlyTotal < thr.From__c) continue; // under limit
				Decimal baseValue = 0;
				if ((thr.cb5p__UpTo__c == 0 || thr.cb5p__UpTo__c == null) || (yearlyTotal < thr.cb5p__UpTo__c)) { // last limit
					baseValue = yearlyTotal - thr.From__c;
				} else {
					baseValue = thr.cb5p__UpTo__c - thr.From__c;
				}
				yearlyTax += baseValue * thr.cb5__SingleValue__c;
				if (yearlyTotal < thr.cb5p__UpTo__c) break;
			}
			for (cb5__CBNonFinancialItem__c item : items) {
				Decimal fraction = item.cb5__Value__c / yearlyTotal;
				item.cb5__Value__c = (yearlyTax * fraction).setScale(2);
			}
		} catch (Exception e) {
			System.debug('applyTaxThresholds EXCEPTION: ' + e);
		}
	}

}