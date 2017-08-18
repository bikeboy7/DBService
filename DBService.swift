//
//  DBService.swift
//  fmdb
//
//  Created by boy on 2017/4/27.
//  Copyright © 2017年 xys. All rights reserved.
//

import UIKit
import FMDB
import RxSwift


class DBService: NSObject {
    
    static let share: DBService = DBService.init(dbName: "App")
    
    private var _dbQueue: FMDatabaseQueue
    
    
    /// 初始化数据库
    ///
    /// - Parameter dbName: 数据库名字
    private init(dbName: String) {
        let dbPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first?.appending("/\(dbName).sql")
        
        print("---------dbPath---------\(dbPath)")
        _dbQueue = FMDatabaseQueue.init(path: dbPath)
        
    }
    
    private func transaction(_ items : Array<Any>, _ block: @escaping (Any) -> (SqlInfo)) -> Observable<AppResult<Any>> {
        
        return Observable.create{[weak self] obser -> Disposable in
            
            DispatchQueue.global().async {
                var b: Bool = true
                var error: Error?
                
                self?._dbQueue.inTransaction { (db, rollback) in
                    
                    for item in items {
                        let info = block(item)
                        b = db!.executeUpdate(info.sqlStr, withParameterDictionary: info.arguments)
                        if !b {
                            rollback?.pointee = true
                            error = (db?.lastError())!
                            break
                        }
                    }
                }
                if b {
                    obser.onNext(AppResult.success(items))
                }else {
                    obser.onNext(AppResult.failure(AppError.init(type: .DBError, message: "SQL出错", detail: error)))
                    
                }
            }
           
  
            return Disposables.create()
        }
        
    }
    
    //MARK: 创建表
    func create(classes: Array<SQLObject.Type>) -> Observable<AppResult<Any>> {
       
        return transaction(classes) { item in
            let cls = item as! SQLObject.Type
            return SqlBuilder.createTable(cls: cls)
        }
        
    }
    
    //MARK: 插入
    func insert(entities: Array<SQLObject>) -> Observable<AppResult<Any>> {
        
        return transaction(entities) { item in
            let entity = item as! SQLObject
            return SqlBuilder.insert(entity: entity)
        }
    }
    
    
    func insert(cls: SQLObject.Type, entityDics: Array<Dictionary<String, Any>>) -> Observable<AppResult<Any>> {
        return transaction(entityDics) { item in
            let dic = item as! Dictionary<String, Any>
            return SqlBuilder.insert(cls: cls, entityDic: dic)
        }
    }
    
    //MARK: 插入或更新
    /// - Returns: entityDics
    func insertOrUpdate(cls: SQLObject.Type, entityDics: Array<Dictionary<String, Any>>) -> Observable<AppResult<Any>> {
        
        guard entityDics.count > 0 else {
            return Observable.just(AppResult.success(entityDics))
        }
        
        var whereDics: Array<Dictionary<String, Any>> = []
        
        var allIds: Array<Any> = []
        let needInsertIds: NSMutableArray = []
        var needUpdatetIds: Array<Any> = []
        
        var needUpdateEntitys: Array<SQLObject> = []
        var needInsertDics: Array<Dictionary<String, Any>> = []
        
        
        for entity in entityDics {
            whereDics.append([cls.primarykey(): entity[cls.primarykey()]!])
            allIds.append(entity[cls.primarykey()]!)
            needInsertIds.add(entity[cls.primarykey()]!)

        }
        
        if let exist = self.queryResult(cls: cls, whereDics: whereDics, limit: 0, offset: 0), exist.count > 0 {
            //本地已有的
            for obj in exist {
                
                needInsertIds.remove(obj.value(forKey: cls.primarykey())!)
                
                needUpdatetIds.append(obj.value(forKey: cls.primarykey())!)
                
                needUpdateEntitys.append(obj)
                
            }
        }
        
        
        for dic in entityDics {
            for id in needInsertIds {
                
                if let id = id as? Int, let dicId = dic[cls.primarykey()] as? Int, id == dicId {
                    
                    needInsertDics.append(dic)
                    
                    break
                }
                
                if let id = id as? String, let dicId = dic[cls.primarykey()] as? String, id == dicId {
                    
                    needInsertDics.append(dic)
                    
                    break
                }
            }
            
            if needInsertDics.count == needInsertIds.count {
                break
            }
        }
        
       
        return Observable<AppResult<Any>>
            .create {[weak self] (obser) -> Disposable in
                //更新需要更新的
                if needUpdatetIds.count == 0 {
                    obser.onNext(AppResult.success(true))
                }else {
                    self?.update(entities: needUpdateEntitys)
                        .subscribeOnUI(onNext: { (result) in
                            result.handle(showHintVc: nil, successBlock: { (_) in
                                obser.onNext(AppResult.success(true))
                                
                            }, failureBolock: { (error) in
                                obser.onNext(AppResult.failure(error))
                            })
                    
                        })
                        .addDisposableTo(disposeBag)
                }
            
            
            return Disposables.create()
           
        }.flatMapLatest {[weak self] (result) in
            //插入需要插入的
            result.flatMap({ (_) -> Observable<AppResult<Any>> in
                if needInsertDics.count == 0 {
                    return Observable.just(AppResult.success(true))
                }else {
                    return self!.insert(cls: cls, entityDics: needInsertDics)
                }
                
            })
        }
        .map({ (result) -> AppResult<Any> in
            
            if result.isSuccess {
                return AppResult.success(entityDics)
            }
            
            return result
        })
        
        
    }
    
    
    //MARK: 先删除再更新
    func deleteAndInsert(entities: Array<SQLObject>) -> Observable<AppResult<Any>> {
        
        return delete(entities: entities).flatMapLatest({[weak self] (result) in
            result.flatMap({[weak self] (value) -> Observable<AppResult<Any>> in
                self!.insert(entities: entities)
            })
        })
        
    }
    
    
    func deleteAndInsert(cls: SQLObject.Type, entityDics: Array<Dictionary<String, Any>>) -> Observable<AppResult<Any>> {
        return delete(cls: cls, entityDics: entityDics).flatMapLatest({[weak self] (result) in
            result.flatMap({ (value) -> Observable<AppResult<Any>> in
                self!.insert(cls: cls, entityDics: entityDics)
            })
        })
        
    }
    
    
    

    
    //MARK: 删除
    func delete(entities: Array<SQLObject>) -> Observable<AppResult<Any>> {
        
        return transaction(entities) { item in
            let entity = item as! SQLObject
            return SqlBuilder.delete(entity: entity)
        }
        
    }
    
    func delete(classes: Array<SQLObject.Type>) -> Observable<AppResult<Any>> {
        return transaction(classes) { item in
            let cls = item as! SQLObject.Type
            return SqlBuilder.delete(cls: cls, whereDic: nil)
        }
        
    }
    
    func delete(cls: SQLObject.Type, whereDics: Array<Dictionary<String, Any>>? = nil) -> Observable<AppResult<Any>> {
        if let whereDics = whereDics  {
            return transaction(whereDics) { item in
                let whereDic = item as! Dictionary<String, Any>
                return SqlBuilder.delete(cls: cls, whereDic: whereDic)
            }
        }else {
            return transaction([cls]) { item in
                return SqlBuilder.delete(cls: cls, whereDic: nil)
            }
        }
       
    }
    
    
    
    func delete(cls: SQLObject.Type, entityDics: Array<Dictionary<String, Any>>) -> Observable<AppResult<Any>> {
        return transaction(entityDics) { item in
            let entityDic = item as! Dictionary<String, Any>
            return SqlBuilder.delete(cls: cls, entityDics: entityDic)
        }
        
    }
    
    //MARK: 更改
    func update(entities: Array<SQLObject>) -> Observable<AppResult<Any>> {
        return transaction(entities) { item in
            let entity = item as! SQLObject
            return SqlBuilder.update(entity: entity)
        }
    }
    
    func update(cls: SQLObject.Type, contence: Dictionary<String, Any>, whereDic: Dictionary<String, Any>? = nil) -> Observable<AppResult<Any>> {
        return transaction([contence]) { item in
            let dic = item as! Dictionary<String, Any>
            return SqlBuilder.update(cls: cls, content: dic, whereDic: whereDic)
        }
    }
    
    //MARK: 查询
    func query(cls: SQLObject.Type, whereDics: Array<Dictionary<String, Any>>?, limit: Int, offset: Int) -> Observable<AppResult<Any>>  {
        
        return Observable.create{[weak self] obser -> Disposable in
        
            var resultArray = Array<Any>()
            var err: Error?
            
            self?._dbQueue.inDatabase { (db) in
            
                let info = SqlBuilder.query(cls: cls, whereDics: whereDics, limit: limit, offset: offset)
                
                do {
                    let set = try db?.executeQuery(info.sqlStr, values: nil)
                    
                    while set!.next() {
                        
                        let result = set!.resultDictionary()
                        
                        let propertys = cls.propertys()
                        
                        let cls = cls as AnyClass
                        let obj = cls.alloc()
                        
                        
                        for (key,value) in result! {
                            
                            //String 类型 复制 nil为闪退
                            if !(value as AnyObject).isEqual(NSNull.init()) {
                                obj.setValue(value, forKey: key as! String)
                                
                            }else{
                                
                                
                                let provalue =  propertys[key as! String] as! String
                                
                                if provalue.contains("NSString") {
                                    obj.setValue("", forKey: key as! String)
                                    
                                }else{
                                    
                                    obj.setValue(value, forKey: key as! String)
                                }
                                
                            }
                        }
                        resultArray.append(obj)
                    }
                    
                    
                }catch {
                    err = error
                }
            }
            if let err = err {
                obser.onNext(AppResult.failure(AppError.init(type: .DBError, message: "查询出错", detail: err)))
            }else {
                obser.onNext(AppResult.success(resultArray))
            }

            return Disposables.create()
        }
        
        
    }
    
    //直接返回查询结果
    func queryResult(cls: SQLObject.Type, whereDics: Array<Dictionary<String, Any>>?, limit: Int, offset: Int) -> Array<SQLObject>? {
        
        var resultArray = Array<SQLObject>()
        
        _dbQueue.inDatabase { (db) in
            
            let info = SqlBuilder.query(cls: cls, whereDics: whereDics, limit: limit, offset: offset)
            
            do {
                let set = try db?.executeQuery(info.sqlStr, values: nil)
                
                while set!.next() {
                    
                    let result = set!.resultDictionary()
                    
                    let propertys = cls.propertys()
                    
                    let cls = cls as AnyClass
                    let obj = cls.alloc()
                    
                    
                    for (key,value) in result! {
                        
                        //String 类型 复制 nil为闪退
                        if !(value as AnyObject).isEqual(NSNull.init()) {
                            obj.setValue(value, forKey: key as! String)
                            
                        }else{
                            
                            let provalue =  propertys[key as! String] as! String
                            
                            if provalue.contains("NSString") {
                                obj.setValue("", forKey: key as! String)
                                
                            }
                        }
                    }
                    resultArray.append(obj as! SQLObject)
                }
                
            }catch {
                print("查询失败")
                print(error)
            }
        }
       
        return resultArray
        
    }
    
    ///默认返回查到的第一个
    func query(cls: SQLObject.Type, whereDics: Array<Dictionary<String, Any>>?) -> SQLObject? {
       
        let result = queryResult(cls: cls, whereDics: whereDics, limit: 0, offset: 0)
        if (result?.count)! > 0 {
            return result?[0]
        }else {
            return nil
        }
    }
    


    
}
