//
//  SqlBuilder.swift
//  FMDBTest
//
//  Created by boy on 2017/4/27.
//  Copyright © 2017年 xys. All rights reserved.
//

import UIKit
import SwiftyJSON


struct SqlInfo {
    
    var sqlStr: String = ""  // sql语句
    var arguments: Dictionary<String, Any>? = [:] // sql参数
    
}

/// 用来生成各种sql语句
class SqlBuilder: NSObject {
    
    //MARK: 创建表
    class func createTable(cls: SQLObject.Type) -> SqlInfo {
        
        var sql = "CREATE TABLE IF NOT EXISTS \(cls.classNmae()) ("
        
        let primarykey = cls.primarykey()
        
        
        for (key, value) in cls.propertys() {
            
            if primarykey.characters.count > 0, primarykey == key {
                
                sql.append("\(key) INTEGER PRIMARY KEY,")

                continue
            }
            
            let value = value as AnyObject
            
            if value.contains("NSNumber") {
                sql.append("\(key) INTEGER,")
            }else if value.contains("NSData") {
                sql.append("\(key) BLOB,")
            }else if value.contains("NSString") {
                sql.append("\(key) TEXT,")
            }else if value.contains("TB") {//bool
                sql.append("\(key) INTEGER,")
            }else if value.contains("Tq") {//int
                sql.append("\(key) INTEGER,")
            }else if value.contains("Tf") {//float
                sql.append("\(key) REAL,")
            }else if value.contains("Td") {//double
                sql.append("\(key) REAL,")
            }else {//不支持的话，则忽略不创建
                continue
            }
            
        }
        sql = sql.substring(to: sql.index(sql.startIndex, offsetBy: sql.characters.count - 1))
        sql.append(")")
        return SqlInfo(sqlStr: sql, arguments: nil)
    }
    
    //MARK: 插入
    
    /// 插入新数据
    ///
    /// - Parameter entity: 实例对象
    /// - Returns: （插入语句，对象字典值）
    class func insert(entity: SQLObject) -> SqlInfo {
        
        let cls = entity.classForCoder as! SQLObject.Type
        let propertys = cls.propertys()
        var arguments: Dictionary<String, Any> = [:]
        
        
        var sql = "INSERT INTO \(cls.classNmae()) ("
        var valueStr = "values("
        
        //"insert into QFStu(Name,Age,Class,RegisterTime,Money,Birthday)values(?,?,?,?,?,?)"
        var i: Int = 0
        for (key, _) in propertys{
            
            let entiyValue = entity.value(forKey: key)!
            
            sql.append("\(key)")
            valueStr.append(":\(key)")
            
            if i < propertys.count - 1 {
                sql.append(",")
                valueStr.append(",")
            }else {
                sql.append(")")
                valueStr.append(")")
            }
            i += 1

          
            arguments[key] = entiyValue
            
        }
        
        sql.append(valueStr)
        
        return SqlInfo(sqlStr: sql, arguments: arguments)
    }
    
    /// 插入新数据
    ///
    /// - Parameter entity: 字典
    /// - Returns: （插入语句，对象字典）
    class func insert(cls: AnyClass, entityDic: Dictionary<String, Any>) -> SqlInfo {
        
        let cls = cls as! SQLObject.Type
        let propertys = cls.propertys()
        var arguments: Dictionary<String, Any> = [:]
        
        
        var sql = "INSERT INTO \(cls.classNmae()) ("
        var valueStr = "values("
        
        //"insert into QFStu(Name,Age,Class,RegisterTime,Money,Birthday)values(?,?,?,?,?,?)"
        var i: Int = 0
        for (key, value) in propertys{
            let value = value as AnyObject

            var entiyValue = entityDic[key]
            if entiyValue == nil {
                if value.contains("NSString") {
                    entiyValue = ""
                }else {
                    entiyValue = 0
                }
            }
            
            sql.append("\(key)")
            valueStr.append(":\(key)")
            
            if i < propertys.count - 1 {
                sql.append(",")
                valueStr.append(",")
            }else {
                sql.append(")")
                valueStr.append(")")
            }
            i += 1
            
            
            arguments[key] = entiyValue
            
        }
        
        sql.append(valueStr)
        
        return SqlInfo(sqlStr: sql, arguments: arguments)
    }
    
    
    /// 删除
    ///
    /// - Parameters:
    ///   - cls: 要删除的表
    ///   - strWhere: 条件语句 例如：id=7
    /// - Returns: 删除语句
    class func delete(cls: SQLObject.Type, whereDic: Dictionary<String,Any>? = nil) -> SqlInfo {
        
        if let whereDic = whereDic {
            var sqlStr = "DELETE FROM \(cls.classNmae()) WHERE"
            var i = 0
            for (key, value) in whereDic {
                sqlStr = sqlStr + " \(key)='\(JSON(value).stringValue)'"
                
                if i != whereDic.count - 1 {
                    sqlStr = sqlStr + " and"
                }
                
                i += 1

            }
            
            return SqlInfo(sqlStr: sqlStr, arguments: whereDic)

            
            //return SqlInfo(sqlStr: "DELETE FROM \(cls.classNmae()) WHERE \(whereDic.first!.key)=\(whereDic.first!.value)", arguments: whereDic)
        }else {
            return SqlInfo(sqlStr: "DELETE FROM \(cls.classNmae())", arguments: nil)
        }
    }
    
    class func delete(entity: SQLObject) -> SqlInfo {
        let primarykey = entity.classForCoder.primarykey()

        return SqlInfo(sqlStr: "DELETE FROM \(entity.classForCoder.classNmae()) WHERE \(primarykey)='\(entity.value(forKey: primarykey)!)'", arguments: nil)
    }
    
    class func delete(cls: SQLObject.Type, entityDics: Dictionary<String,Any>) -> SqlInfo {
        let primarykey = cls.primarykey()
        
        return SqlInfo(sqlStr: "DELETE FROM \(cls.classNmae()) WHERE \(primarykey)=\(entityDics[primarykey]!)", arguments: nil)
    }
    
    
    /// 更改数据
    ///
    /// - Parameter entity: 更新的对象
    /// - Returns:
    class func update(entity: SQLObject) -> SqlInfo {
        
        let cls = entity.classForCoder as! SQLObject.Type
        let propertys = cls.propertys()
        var arguments: Dictionary<String, Any> = [:]
        
        var sql = "UPDATE \(cls.classNmae()) SET "
        
        //"update userInfo set name='xxx',age='17',image='xxx'"
        var i: Int = 0
        for (key, _) in propertys{
            
            let entiyValue = entity.value(forKey: key)!
            
            sql.append("\(key)='\(entiyValue)'")
          
            if i < propertys.count - 1 {
                sql.append(",")
            }
            i += 1
            
            arguments[key] = entiyValue
        }
        
        if let primaryKey = entity.value(forKey: cls.primarykey()) {
            sql.append(" WHERE \(cls.primarykey())='\(primaryKey)'")
        }
        
        return SqlInfo(sqlStr: sql, arguments: nil)
    }
    
    /// 更改数据
    ///
    /// - Parameters:
    ///   - cls: cls
    ///   - content: content
    ///   - whereDic: 如果为空，会检查content是否有primarykey，有则更新对应的内容
    /// - Returns: return value description
    class func update(cls: SQLObject.Type, content: Dictionary<String, Any>, whereDic: Dictionary<String, Any>? = nil) -> SqlInfo {
        
        var arguments: Dictionary<String, Any> = [:]
        
        
        var sql = "UPDATE \(cls.classNmae()) SET "
        
        //"update userInfo set name='xxx',age='17',image='xxx'"
        var i: Int = 0
        for (key, value) in content {
            sql.append("\(key)='\(value)'")
            if i < content.count - 1 {
                sql.append(",")
            }
            i += 1
            
            arguments[key] = value
        }
        
        if let whereDic = whereDic {
            var whereStr = " WHERE"
            var i = 0
            for (key, value) in whereDic {
                whereStr.append(" \(key)='\(JSON(value).stringValue)'")
                
                if i != whereDic.count - 1 {
                    whereStr.append(" and")
                }
                
                i += 1
                
            }
            
            sql.append(whereStr)
            
            
//            if whereDic.count > 0 {
//                sql.append(" WHERE \(whereDic.first!.key)='\(whereDic.first!.value)'")
//            }
        }else if let primaryKey = content["\(cls.primarykey())"] {
            sql.append(" WHERE \(cls.primarykey())='\(primaryKey)'")
        }
        
        return SqlInfo(sqlStr: sql, arguments: arguments)
    }
    
    
    
    /// 查询
    ///
    /// - Parameters:
    ///   - cls: 类
    ///   - whereDic: 查询条件
    ///   - limit: 查询条数，小于1则为全部
    ///   - offset: offset
    /// - Returns: 查询语句
    class func query(cls: SQLObject.Type, whereDics: Array<Dictionary<String, Any>>? = nil, limit: Int, offset: Int) -> SqlInfo {
        //"select * from FlightGoods where dayFlightId= '7'"
        
        //select * from tab_name where 组号='001组'  and to_char(日期,'yyyy-mm-dd')='2013-04-15' and 姓名1='小王' or 姓名2='小王' or 姓名3='小王' or 姓名4='小王'
        
        var sql = "SELECT * FROM \(cls.classNmae())"
        
//        if let dic = whereDic {
//            if dic.count > 0 {
//                sql.append(" WHERE ")
//            }
//            for (key, value) in whereDic! {
//                sql.append("\(key)='\(value)'")
//            }
//        }
        
        if let whereDics = whereDics {
            var whereStr = " WHERE"
            var j = 0
            for whereDic in whereDics {
                
                var i = 0

                for (key, value) in whereDic {
                    whereStr.append(" \(key)='\(JSON(value).stringValue)'")
                    
                    if i != whereDic.count - 1 {
                        whereStr.append(" and")
                    }
                    
                    i += 1
                    
                }
                
                
                if j != whereDics.count - 1 {
                    whereStr.append(" or")
                }
                
                j += 1

            
            }
            
            
            sql.append(whereStr)
           
        }
        
        
        if limit > 0 {
            sql.append(" limit \(limit)")
        }
        
        if offset > 0 {
            sql.append(" offset \(offset)")
        }
        
        return SqlInfo(sqlStr: sql, arguments: nil)
    
    }
    
    
    

}
