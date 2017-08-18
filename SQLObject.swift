//
//  SQLObject.swift
//  fmdb
//
//  Created by boy on 2017/4/27.
//  Copyright © 2017年 xys. All rights reserved.
//

import UIKit

///子类的基本数据或nsnumber默认是0
class SQLObject: NSObject {
    
    
    /// 子类重写此方法才有会主键，默认是没有主键
    ///
    /// - Returns: 主键
    class func primarykey() -> String {
        return ""
    }
    
    
    
    /// 存储所有子类的属性字典
    private static var _propertys: Dictionary<String, Any> = [:]
    
    /// 获取所有属性名称和对应的类型，先从_propertys取，没有再遍历属性
    ///
    /// - Returns: Dictionary<属性名称, 属性类型>
    static func propertys() -> Dictionary<String, Any> {
       
        var propertys: Dictionary<String, Any>? = _propertys[self.classNmae()] as? Dictionary<String, Any>
        
        
        
        if let propertys = propertys, propertys.count > 0 {
            return propertys
        }else{
            var count: UInt32 = 0
            
            let properties = class_copyPropertyList(self, &count)
            
            var dic: Dictionary<String, Any> = [:]
            
            // Swift中类型是严格检查的，必须转换成同一类型
            for i in 0 ..< Int(count) {
                // UnsafeMutablePointer<objc_property_t>是
                // 可变指针，因此properties就是类似数组一样，可以
                // 通过下标获取
                let property = properties?[i]
                
                let propertyName = String.init(cString: property_getName(property), encoding: .utf8)
                let attributeName = String.init(cString: property_getAttributes(property), encoding: .utf8)
                
                dic.updateValue(attributeName!, forKey: propertyName!)
                
            }
            
            // 不要忘记释放内存，否则C语言的指针很容易成野指针的
            free(properties)
            
            propertys = dic
            _propertys[self.classNmae()] = propertys

        }
        
        return propertys!
        
    }
    
    /// 获取当前类名
    ///
    /// - Returns: 类名
    static func classNmae() -> String {
        var name = String.init(utf8String: class_getName(self))!
        let range = name.range(of: ".")?.lowerBound
        name = name.substring(from: name.index(after: range!))
        
        return name
        
    }
   
    /// 获取对象的所有属性名称和对应的值
    ///
    /// - Returns: Dictionary<属性名称, 属性值>
    func allValue() -> Dictionary<String, Any> {
        var count: UInt32 = 0
        
        let properties = class_copyPropertyList(self.classForCoder, &count)
        
        var dic: Dictionary<String, Any> = [:]
        
        
        // Swift中类型是严格检查的，必须转换成同一类型
        for i in 0 ..< Int(count) {
            // UnsafeMutablePointer<objc_property_t>是
            // 可变指针，因此properties就是类似数组一样，可以
            // 通过下标获取
            let property = properties?[i]
            
            let propertyName = String.init(cString: property_getName(property), encoding: .utf8)
            //let value = String.init(cString: property_getAttributes(property), encoding: .utf8)
            
            let value = self.value(forKey: propertyName!)
            
            //如果不是数字就是string
            if value is NSNumber {
                dic.updateValue(value ?? NSNumber(value: 0), forKey: propertyName!)
            }else if let value = value as? Int {
                dic.updateValue(NSNumber(value: value), forKey: propertyName!)
            }else if let value = value as? Double {
                dic.updateValue(NSNumber(value: value), forKey: propertyName!)
            }else if let value = value as? Float {
                dic.updateValue(NSNumber(value: value), forKey: propertyName!)
            }else if let value = value as? Bool {
                dic.updateValue(NSNumber(value: value), forKey: propertyName!)
            }else if value is String {
                dic.updateValue(value ?? "", forKey: propertyName!)
            }else {
                dic.updateValue("", forKey: propertyName!)
            }
            
            
        }
        
        // 不要忘记释放内存，否则C语言的指针很容易成野指针的
        free(properties)
        
        return dic
        
    }
    
    override func setValue(_ value: Any?, forUndefinedKey key: String) {

    }
    
    override func setValue(_ value: Any?, forKey key: String) {
        
        if let type = self.classForCoder.propertys()[key] as? String {
            // 基本数据类型 设为nil会崩，所以将其设为0
            if (type.contains("Tq") || type.contains("Tf") || type.contains("Td")) && value == nil{
                super.setValue(0, forKey: key)
                return
            }
            
            super.setValue(value, forKey: key)
        }
    }
    
    init(_ value: Dictionary<String, Any> = [:]) {
        super.init()
        if value.count > 0 {
            self.setValuesForKeys(value)
        }
    }


}
