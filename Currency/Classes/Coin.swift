//
//  Coin.swift
//  Currency
//
//  Created by Nuno Coelho Santos on 23/04/2016.
//  Copyright © 2016 Nuno Coelho Santos. All rights reserved.
//

import Foundation
import CoreData
import SWXMLHash

class Coin {
    var code: String!
    var rate: Double!
    var locale: String?
    var symbol: String?
    var decimals: Int!
    var symbolPosition: String?
    var useLocalization: Bool = true
    var useSymbol: Bool = true
    var useCustomSymbol: Bool = false
    
    init(withCode code: String, update: Bool = true, remember: Bool = true) {
        setTo(code, update: update, remember: remember)
    }
    
    func setTo(code: String, update: Bool = true, remember: Bool = true) {
        let currency = getRecord(code)
        self.code = currency.code
        self.rate = currency.rate
        self.locale = currency.locale
        self.symbol = currency.symbol
        self.decimals = currency.decimals
        self.symbolPosition = currency.symbolPosition
        self.useLocalization = currency.useLocalization
        self.useSymbol = currency.useSymbol
        self.useCustomSymbol = currency.useCustomSymbol
        if update {
            self.update()
        }
        if remember {
            self.recordAsSelected()
        }
    }
    
    func update() {
        updateRate()
    }
    
    func recordAsSelected() {
        // CoreData setup.
        let managedObjectContext: NSManagedObjectContext!
        let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        managedObjectContext = appDelegate.managedObjectContext as NSManagedObjectContext
        var currency: Currency
        
        // CoreData fetching.
        let fetch = NSFetchRequest(entityName: "Currency")
        let predicate = NSPredicate(format: "%K == %@", "code", self.code)
        fetch.predicate = predicate
        fetch.fetchLimit = 1
        
        do {
            currency = try managedObjectContext.executeFetchRequest(fetch).first as! Currency
        } catch {
            fatalError("Error fetching currency: \(error)")
        }
        
        // Update object.
        currency.setValue(NSDate(), forKey: "lastSelected")
        
        // CoreData save.
        do {
            try managedObjectContext.save()
        } catch {
            fatalError("Error saving currency: \(error)")
        }
        
        print("Currency \(self.code) last selected at: \(NSDate())")
    }
    
    private func getRecord(code: String) -> (
            name: String,
            code: String,
            rate: Double,
            locale: String?,
            symbol: String?,
            decimals: Int,
            symbolPosition: String?,
            useLocalization: Bool,
            useSymbol: Bool,
            useCustomSymbol: Bool) {
        
        // CoreData setup.
        let managedObjectContext: NSManagedObjectContext!
        let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        managedObjectContext = appDelegate.managedObjectContext as NSManagedObjectContext
        var currency: Currency
        
        // CoreData fetching.
        let fetch = NSFetchRequest(entityName: "Currency")
        let predicate = NSPredicate(format: "%K == %@", "code", code)
        fetch.predicate = predicate
        fetch.fetchLimit = 1
        
        do {
            currency = try managedObjectContext.executeFetchRequest(fetch).first as! Currency
        } catch {
            fatalError("Error fetching currency: \(error)")
        }
        
        let name: String = currency.name_en!
        let code: String = code
        let rate: Double = Double(currency.rateFromUSD!)
        let locale: String = currency.locale!
        let symbol: String = currency.symbol!
        let decimals: Int = Int(currency.decimals!)
        let symbolPosition: String? = currency.symbolPosition
        let useLocalization: Bool = currency.useLocalization
        let useSymbol: Bool = currency.useSymbol
        let useCustomSymbol: Bool = currency.useCustomSymbol
        
        return(name, code, rate, locale, symbol, decimals, symbolPosition, useLocalization, useSymbol, useCustomSymbol)
    }
    
    private func updateRate() {
        
        // Start by showing the network indicator.
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        let url = NSURL(string: "https://query.yahooapis.com/v1/public/yql?q=" +
            "select%20*%20from%20yahoo.finance.xchange%20where%20pair%20in%20(" +
            "%22USD" + self.code + "%22)&diagnostics=true&env=store%3A%2F%2F" +
            "datatables.org%2Falltableswithkeys")
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            
            guard data != nil else {
                print("Error performing Yahoo query.")
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                return
            }
            
            let xml = SWXMLHash.parse(data!)
            
            guard let rate = xml["query"]["results"]["rate"]["Rate"].element?.text else {
                print("Could not parse XML request.")
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                return
            }
            
            // Update currency record on database.
            self.updateRateRecord(Double(rate)!)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            
        }
        
        task.resume()
        
    }
    
    private func updateRateRecord(rate: Double) {
        // CoreData setup.
        let managedObjectContext: NSManagedObjectContext!
        let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        managedObjectContext = appDelegate.managedObjectContext as NSManagedObjectContext
        var currency: Currency
        
        // CoreData fetching.
        let fetch = NSFetchRequest(entityName: "Currency")
        let predicate = NSPredicate(format: "%K == %@", "code", self.code)
        fetch.predicate = predicate
        fetch.fetchLimit = 1
        
        do {
            currency = try managedObjectContext.executeFetchRequest(fetch).first as! Currency
        } catch {
            print("Error fetching currency: \(error)")
            return
        }
        
        // Update object.
        currency.setValue(rate, forKey: "rateFromUSD")
        
        // CoreData save.
        do {
            try managedObjectContext.save()
        } catch {
            print("Error saving currency: \(error)")
            return
        }
        
        print("Currency \(self.code) updated with the rate: \(rate)")
    }
    
}