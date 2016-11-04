//
//  NSObject+XZHJSONMapping.m
//  XZHRuntimeDemo
//
//  Created by XiongZenghui on 16/9/11.
//  Copyright © 2016年 com.cn.fql. All rights reserved.
//

#import "NSObject+XZHJSONMapping.h"
#import <objc/message.h>
#import "XZHRuntime.h"

static BOOL _isNeedDefaultJSONValueHandle = YES;
void xzh_setNoNeedDefaultJSONValueHandle() {
    _isNeedDefaultJSONValueHandle = NO;
}

/**
 *  属性映射jsonkey的类型
 */
typedef NS_ENUM(NSInteger, XZHPropertyMappedToJsonKeyType) {
    /**
     *  映射的jsonkey
     */
    XZHPropertyMappedToJsonKeyTypeSimple             = 1,
    /**
     *  带有路径的jsonkey
     */
    XZHPropertyMappedToJsonKeyTypeKeyPath,
    /**
     *  映射多个jsonkey
     */
    XZHPropertyMappedToJsonKeyTypeKeyArray,
};

@class XZHPropertyMapper;


typedef struct XZHModelContext {
    void *modelSelf;        // json对象设置到的Foundation对象
    void *classMapper;      // Foundation对象的objc_class实例的解析类XZHClassMapper对象
    void *jsonDic;          // 将要解析设置到Foundation对象 JSON Object(1.string 2.data 3.dic)
}XZHModelContext;

/**
 *  日期字符串格式化
 */
static xzh_force_inline NSDateFormatter* XZHDateFormatter(__unsafe_unretained NSString *dateFormat);

/**
 *  单独对NSString对象做各种null字符串的处理，均转换为@""
 */
static xzh_force_inline NSString* XZHConvertNullNSString(__unsafe_unretained id value);

/**
 *  json字符串转换成NSDictioanry
 */
static xzh_force_inline NSDictionary* XZHJSONStringToDic(__unsafe_unretained NSString *jsonString);

/**
 *  解析 @{@"address" : @[@"address1", @"address2", @"address3", @"user.city.address"]} 属性映射多个jsonkey时
 */
static xzh_force_inline NSArray* XZHGetPropertyMultiJSONKeyArray(__unsafe_unretained NSArray *keyArr);

/**
 *  从NSDictionary中使用keypath获取值，防止崩溃处理
 */
static xzh_force_inline id XZHGetValueFromDictionaryWithKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSString *keyPath);

/**
 *  NSString/NSNumber/NSNull >>> NSNumber
 */
static xzh_force_inline NSNumber* XZHNumberWithValue(__unsafe_unretained id value);

/**
 *  将Objective-C实体类对象的属性值转换成NSNumber
 */
static xzh_force_inline NSNumber* XZHNumberWithModelProperty(__unsafe_unretained id object, __unsafe_unretained XZHPropertyMapper *mapper);

/**
 *  根据Objective-C实体类对象的属性Ivar的类型，设置对于的默认值
 */
//static xzh_force_inline id XZHDefaultFoundationObjectValueWithPropertyMapper(__unsafe_unretained id value, __unsafe_unretained XZHPropertyMapper *mapper);

/**
 *  将id value根据mapper记录的jsonkey
 *
 *  @param value  Objective-C id 对象
 *  @param object 实体类对象
 *  @param mapper 记录jsonkey与objc_property如何映射
 */
static void XZHSetValueToProperty(__unsafe_unretained id value, __unsafe_unretained id object, __unsafe_unretained XZHPropertyMapper *mapper);

/**
 *  遍历ClassMapper中两个ProeprtyMapper对象数组，从context->_json中取出对应json value，设置到 model对象
 *
 *  @param value    XZHPropertyMapper
 *  @param context  XZHModelContext
 */
static void XZHModelCFDictionaryApplierFunction(const void *key, const void *value, void *context);

static void XZHModelSimpleKeyCFArrayApplierFunction(const void *value, void *context);
static void XZHModelKeyPathCFArrayApplierFunction(const void *value, void *context);
static void XZHModelKeyArrayCFArrayApplierFunction(const void *value, void *context);

/**
 *  负责描述一个XZHPropertyModel对象
 
 1. 主要是描述property与jsonkey的映射关系:
 >>> {@"name":@"name"}
 >>> {@"name":@"user.name"}
 >>> {@"name":@"name", @"title":@"name", @"tip":@"name"}  多个属性对应同一个jsonkey
 >>> {@"id": @[@"id", @"ID", @"Id", @"Uid"]}   一个属性对应多个jsonkey
 >>> {@"uid": @[@"id", @"ID", @"Id", @"Uid"], @"pid": @[@"id", @"ID", @"Id", @"Uid"]}  结合上面两种情况
 
 2. Ivar类型是否支持归档
 >>> 类型限制
 >>> 必须实现setter与getter访问方法
 */
@interface XZHPropertyMapper : NSObject {
    @package
    
    /**
     *  描述的objc_property实例
     */
    XZHPropertyModel            *_property;
    
    /**
     *  属性所属的[NSObject类 class]
     */
    Class                       _generacCls;
    
    /**
     *  属性变量Ivar的类型Class
     */
    Class                       _ivarClass;
    
    /**
     *  容器属性变量为容器类型（Array、Dic、Set）时，内部子对象的类型Class
     */
    Class                       _containerCls;
    
    /**
     *  Ivar的类型编码
     */
    XZHTypeEncoding             _typeEncoding;
    
    /**
     *  Ivar的类型编码字符串
     */
    NSString                    *_typeEncodingString;
    
    /**
     *  Ivar的Foundation类型
     */
    XZHFoundationType           _foundationType;
    
    /**
     *  Ivar是否是c基本数值类型(int、float、double、long ....)
     */
    BOOL                        _isCNumber;
    
    /**
     *  Ivar是否是NSNumber基本数值类型
     */
    BOOL                        _isNSNumber;
    
    /**
     *  Ivar类型是否支持归档
     */
    BOOL                        _isCanArchived;
    
    /**
     *  是否能够使用KVC
     */
    BOOL                        _isKVCCompatible;
    
    /**
     *  是否能够使用setter/getter
     */
    BOOL                        _isGetterAccess;
    BOOL                        _isSetterAccess;
    
    /**
     *  记录属性映射的json key的类型
     */
    XZHPropertyMappedToJsonKeyType _mappedToJSONKeyType;
    
    /**
     *  属性映射简单的json key
        @{ @"user":@"user" }
     */
    NSString                    *_mappedToSimpleKey;
    
    /**
        属性映射一个 json key path 路径
        {@"name":@"user.name"}
     */
    NSString                     *_mappedToKeyPath;
    
    /**
     *  一个属性 映射 多个json key
         @{
             //属性名 : json key
             @"id":@"userId",
             @"id":@"User.id",
             @"id":@"UID",
         }
     */
    NSArray                     *_mappedToKeyArray;
    
    /**
     *  多个实体类属性 映射 同一个json key
         @{
             //属性名 : json key
             @"id"       :@"uid",
             @"userId"   :@"uid",
             @"ID"       :@"uid",
         }
         
         id->userId->ID 链起来
     */
    XZHPropertyMapper         *_next;
}
@end
@implementation XZHPropertyMapper

/**
 *  创建PropertyMapper
 *
 *  @param property         XZHPropertyModel对象
 *  @param containerCls     当属性是容器类型（NSArray、NSDictionary、NSSet）时，内部子对象的类型Class
 *  @param generacCls       属性所属类Class（eg、Dog、Person...）
 */
- (instancetype)initWithPropertyModel:(XZHPropertyModel *)property containerCls:(Class)containerCls generacCls:(Class)generacCls{
    if (self = [super init]) {
        _property = property;
        _ivarClass = property.cls;
        _generacCls = generacCls;
        _typeEncoding = property.typeEncoding;
        _typeEncodingString = property.encodingString;
        _foundationType = property.foundationType;
        _isCNumber = property.isCNumber;
        _isNSNumber = (XZHFoundationTypeNSNumber == _foundationType) || (XZHFoundationTypeNSDecimalNumber == _foundationType);
        _isCanArchived = property.isCanArchived;
        _isKVCCompatible = property.isKVCCompatible;
        _containerCls = containerCls;

        _isSetterAccess = NO;
        _isGetterAccess = NO;
        if (property.setter && ((XZHTypeEncodingPropertyReadonly != (_typeEncoding & XZHTypeEncodingDataTypeMask))))
        {
            _isSetterAccess = YES;
        }
        if (property.getter) {
            _isGetterAccess = YES;
        }
        
        _next = nil;
    }
    return self;
}

@end

@interface XZHClassMapper : NSObject {
    @package
    XZHClassModel               *_classModel;
    
    /**
     *  1、记录所有的属性与jsonkey的映射存储 >>> < jsonkey : PropertyMapper对象 >
     *  {name : name}
     *  {name : user_name}
     *  {name : user.name}
     *  {name1 : name}, {name2 : name}, {name3 : name}
     *  {name : [name1, name2, name3, user.name]}
     *
     *  2. 映射关系为<n属性:1jsonkey>时，使用_next属性依次将映射相同jsonkey的PropertyMapper对象串联起来
     *  >>> PropertyMapper1->PropertyMapper2->PropertyMapper3->nil
     *
     *  key >>> json key
     *  value >>> PropertyMapper对象
     */
    CFDictionaryRef             _jsonKeyMappedPropertyMapperDic;
    
    /**
     *  - 记录所有的属性映射规则
     *  - simple json key
     *  - json keyPath
     *  - json keyArray
     */
    CFMutableArrayRef                  _allPropertyMappers;
    CFMutableArrayRef                  _simplePropertyMappers;
    CFMutableArrayRef                  _keyPathPropertyMappers;
    CFMutableArrayRef                  _keyArrayPropertyMappers;
    
    /**
     *  保存容器property对应的class >>> <jsonkey:数组内部对象Class>
     */
    CFDictionaryRef             _objectInArrayClassDic;
    
    /**
     *  记录映射json key总个数
     */
    CFIndex                     _mappedCount;
}

@end
@implementation XZHClassMapper

- (void)dealloc {
    _classModel = nil;
    CFRelease(_jsonKeyMappedPropertyMapperDic);
    CFRelease(_objectInArrayClassDic);
    CFRelease(_allPropertyMappers);
    CFRelease(_simplePropertyMappers);
    CFRelease(_keyPathPropertyMappers);
    CFRelease(_keyArrayPropertyMappers);
}

/**
 *  根据传入的objc_class实例生成 ClassMapper ，并使用objc_class名字进行缓存 ClassMapper
 *
 *  ClassMapper 的结构:
 *      - ClassModel
 *          - Ivar List Model
 *          - Property List Model
 *          - Method List Model
 *      - jsonMappingDic
 *          - json key 1 : PropertyMapper 1
 *          - json key 2 : PropertyMapper 2
 *
 *  PropertyMapper 的结构:
 *      - type encoding 解析
 *      - 记录property如何映射json key
 *          - {name : name}
 *          - {name : user_name}
 *          - {name : user.name}
 *          - {name1 : name}, {name2 : name}, {name3 : name}
 *          - {name : [name1, name2, name3, user.name]}
 */
+ (instancetype)classMapperWithClass:(Class)cls {
    if (cls == Nil) return nil;
    static CFMutableDictionaryRef _cache;
    static dispatch_semaphore_t _semephore;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        _semephore = dispatch_semaphore_create(1);
    });
    
    // 存储 ClassMapper 的key
    const void *clsName =  (__bridge const void *)(NSStringFromClass(cls));
    
    dispatch_semaphore_wait(_semephore, DISPATCH_TIME_FOREVER);
    XZHClassMapper *clsMapper = CFDictionaryGetValue(_cache, clsName);
    dispatch_semaphore_signal(_semephore);
    
    if (!clsMapper) {
        __unsafe_unretained XZHClassModel *clsModel = [XZHClassModel instanceWithClass:cls];//内部已经多线程同步
        clsMapper = [[XZHClassMapper alloc] init];
        clsMapper->_classModel = clsModel;
    
        CFMutableDictionaryRef jsonKeyMappedPropertyMapperDic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFMutableArrayRef jsonKeyMappedPropertyMapperArr = CFArrayCreateMutable(CFAllocatorGetDefault(), 32, &kCFTypeArrayCallBacks);
        CFMutableDictionaryRef objectInArrayClassDic = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFMutableArrayRef allPropertyMappers = CFArrayCreateMutable(CFAllocatorGetDefault(), 32, &kCFTypeArrayCallBacks);
        CFMutableArrayRef simplePropertyMappers = CFArrayCreateMutable(CFAllocatorGetDefault(), 32, &kCFTypeArrayCallBacks);
        CFMutableArrayRef keyPathPropertyMappers = CFArrayCreateMutable(CFAllocatorGetDefault(), 32, &kCFTypeArrayCallBacks);
        CFMutableArrayRef keyArrayPropertyMappers = CFArrayCreateMutable(CFAllocatorGetDefault(), 32, &kCFTypeArrayCallBacks);
        
        // 记录包含当前类父类中所有的Property的临时数组
        NSMutableArray *allPropertyNames = [[NSMutableArray alloc] initWithArray:[clsModel.propertyMap allKeys]];
        
        /**
         *  添加父类的所有property属性，
         *  但是忽略对 NSObject/NSProxy 这两个跟类的解析，
         *  NSObject/NSProxy.superclass == NULL 结束循环条件
         */
        __unsafe_unretained XZHClassModel *clsTmpModel = clsModel;
        while (clsTmpModel && (clsTmpModel.superClassModel != nil)) {
            for (__unsafe_unretained XZHPropertyModel *proM in clsTmpModel.propertyMap.allValues) {
                if (!proM.name) {continue;}//必须存在名字
                if (!proM.setter || !proM.getter) {continue;}//必须实现setter/getter
                [allPropertyNames addObject:proM.name];
            }
            clsTmpModel = clsTmpModel.superClassModel;
        }
        
        // Array、Set、Dictionary容器数组内部元素类型解析
        if ([cls respondsToSelector:@selector(xzh_classInArray)]) {
            NSDictionary *classInArrayDic = [(id<XZHJSONMappingConfig>)cls xzh_classInArray];
            [classInArrayDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull propertyName, id  _Nonnull class, BOOL * _Nonnull stop) {
                if ([propertyName isKindOfClass:[NSString class]]) {
                    if ([class isKindOfClass:[NSString class]]) {
                        Class cls = NSClassFromString(class);
                        if (cls) {CFDictionarySetValue(objectInArrayClassDic, (__bridge const void *)(propertyName), (__bridge const void *)(cls));}
                    } else {
                        Class meta = object_getClass(class);
                        if (meta) {//objc->isa >>>> class, class->isa >>>> meta class
                            CFDictionarySetValue(objectInArrayClassDic, (__bridge const void *)(propertyName), (__bridge const void *)(class));
                        }
                    }
                }
            }];
        }
        
        // 移除忽略映射的属性
        NSArray *ignoreJSONKeys = nil;
        if ([cls respondsToSelector:@selector(xzh_ignoreMappingJSONKeys)]) {
            ignoreJSONKeys = [(id<XZHJSONMappingConfig>)cls xzh_ignoreMappingJSONKeys];
        }
        if (ignoreJSONKeys) {[allPropertyNames removeObjectsInArray:ignoreJSONKeys];}
        
        // 自定义jsonkey与属性映射，<jsonKey:PropertyModel> >>>> <jsonKey:PropertyMapper>
        if ([cls respondsToSelector:@selector(xzh_customerPropertyNameMappingJSONKey)]) {
            NSDictionary *customerJSONKeyMapping = [(id<XZHJSONMappingConfig>)cls xzh_customerPropertyNameMappingJSONKey];
            [customerJSONKeyMapping enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull value, BOOL * _Nonnull stop) {
                id jsonKey = value;
                id propertyName = key;
                
                if ([propertyName isKindOfClass:[NSString class]]) {
                    [allPropertyNames removeObject:propertyName];
                    
                    // 取出ClassModel.propertyMap记录的objc_property的ProeprtyModel
                    __unsafe_unretained XZHPropertyModel *propertyModel = [clsModel.propertyMap objectForKey:propertyName];
                    if (propertyModel) {
                        
                        // 创建新的jsonKey映射的PropertyMapper
                        Class newMapperContainerCls = CFDictionaryGetValue(objectInArrayClassDic, (__bridge const void *)(propertyName));
                        XZHPropertyMapper *newMapper = [[XZHPropertyMapper alloc] initWithPropertyModel:propertyModel containerCls:newMapperContainerCls generacCls:cls];
                        
                        XZHPropertyMappedToJsonKeyType type = 0;
                        if ([jsonKey isKindOfClass:[NSString class]]) {
                            // 情况一、{name : user_name}
                            // 情况二、{name : user.name}
                            // 情况三、{name1 : name}, {name2 : name}, {name3 : name}
                            if ([jsonKey rangeOfString:@"."].location != NSNotFound) {
                                newMapper->_mappedToKeyPath = jsonKey;
                                type = XZHPropertyMappedToJsonKeyTypeKeyPath;
                            } else {
                                newMapper->_mappedToSimpleKey = jsonKey;
                                type = XZHPropertyMappedToJsonKeyTypeSimple;
                            }
                        } else if ([jsonKey isKindOfClass:[NSArray class]]) {
                            // 情况四、{name : [name1, name2, name3, user.name]}
                            newMapper->_mappedToKeyArray = jsonKey;
                            type = XZHPropertyMappedToJsonKeyTypeKeyArray;
                        }
                        
                        // 映射任何类型的jsonkey，都应该按照<n属性:1jsonkey>处理
                        __unsafe_unretained XZHPropertyMapper *preMapper = CFDictionaryGetValue(jsonKeyMappedPropertyMapperDic, (__bridge const void *)(jsonKey));
                        if (preMapper) {
                            newMapper->_next = preMapper;
                        } else {
                            CFArrayAppendValue(allPropertyMappers, (__bridge const void *)(newMapper));
                            switch (type) {
                                case XZHPropertyMappedToJsonKeyTypeSimple: {
                                    CFArrayAppendValue(simplePropertyMappers, (__bridge const void *)(newMapper));
                                    break;
                                }
                                case XZHPropertyMappedToJsonKeyTypeKeyPath: {
                                    CFArrayAppendValue(keyPathPropertyMappers, (__bridge const void *)(newMapper));
                                    break;
                                }
                                case XZHPropertyMappedToJsonKeyTypeKeyArray: {
                                    CFArrayAppendValue(keyArrayPropertyMappers, (__bridge const void *)(newMapper));
                                    break;
                                }
                            }
                        }
                        
                        CFDictionarySetValue(jsonKeyMappedPropertyMapperDic, (__bridge const void *)(jsonKey), (__bridge const void *)(newMapper));
                    }
                }
            }];
        }
        
        // 没有自定义jsonkey与属性映射，<jsonKey:PropertyModel> >>>> <jsonKey:PropertyMapper>
        [allPropertyNames enumerateObjectsUsingBlock:^(NSString * _Nonnull propertyName, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([propertyName isKindOfClass:[NSString class]]) {
                __unsafe_unretained XZHPropertyModel *propertyModel = [clsModel.propertyMap objectForKey:propertyName];
                if (propertyModel) {
                    Class newMapperContainerCls = CFDictionaryGetValue(objectInArrayClassDic, (__bridge const void *)(propertyName));
                    XZHPropertyMapper *newMapper = [[XZHPropertyMapper alloc] initWithPropertyModel:propertyModel containerCls:newMapperContainerCls generacCls:cls];
                    CFArrayAppendValue(jsonKeyMappedPropertyMapperArr, (__bridge void*)newMapper);
                    newMapper->_mappedToSimpleKey = propertyName;
                    CFArrayAppendValue(simplePropertyMappers, (__bridge const void *)(newMapper));
                    CFArrayAppendValue(allPropertyMappers, (__bridge const void *)(newMapper));
                    __unsafe_unretained XZHPropertyMapper *preMapper = CFDictionaryGetValue(jsonKeyMappedPropertyMapperDic, (__bridge const void *)(propertyName));
                    if (preMapper) {
                        newMapper->_next = preMapper;
                    } else {
                        CFArrayAppendValue(allPropertyMappers, (__bridge const void *)(newMapper));
                        CFArrayAppendValue(simplePropertyMappers, (__bridge const void *)(newMapper));
                    }
                    CFDictionarySetValue(jsonKeyMappedPropertyMapperDic, (__bridge const void *)(propertyName), (__bridge const void *)(newMapper));
                }
            }
        }];
        
        clsMapper->_jsonKeyMappedPropertyMapperDic = CFDictionaryCreateCopy(CFAllocatorGetDefault(), jsonKeyMappedPropertyMapperDic);
        clsMapper->_objectInArrayClassDic = CFDictionaryCreateCopy(CFAllocatorGetDefault(), objectInArrayClassDic);
        clsMapper->_allPropertyMappers = allPropertyMappers;
        clsMapper->_simplePropertyMappers = simplePropertyMappers;
        clsMapper->_keyPathPropertyMappers = keyPathPropertyMappers;
        clsMapper->_keyArrayPropertyMappers = keyArrayPropertyMappers;
        clsMapper->_mappedCount = CFArrayGetCount(allPropertyMappers);
        
        dispatch_semaphore_wait(_semephore, DISPATCH_TIME_FOREVER);
        CFDictionarySetValue(_cache, clsName, (__bridge const void *)(clsMapper));
        dispatch_semaphore_signal(_semephore);
    }
    
    return clsMapper;
}

@end

@implementation NSObject (XZHJSONMappingTools)

#pragma mark - JSON To Object

- (instancetype)xzh_modelFromObject:(id)obj {
    return [[self class] xzh_modelFromObject:obj];
}

+ (instancetype)xzh_modelFromObject:(id)obj {
    if (!obj || (id)kCFNull == obj) {return nil;}
    if ([obj isKindOfClass:[NSDictionary class]]) {
        return [self _xzh_modelFromJSONDictionary:(NSDictionary*)obj];
    } else if ([obj isKindOfClass:[NSString class]]) {
        return [self _xzh_modelFromJSONString:(NSString*)obj];
    } else if ([obj isKindOfClass:[NSData class]]) {
        return [self _xzh_modelFromJSONData:(NSData*)obj];
    } else if ([obj isKindOfClass:[NSArray class]]) {
        return [self _xzh_modelFromJSONArray:obj];
    }
    return nil;
}

// NSString >>> NSData >>> NSDictionary
+ (instancetype)_xzh_modelFromJSONString:(NSString *)jsonString {
    if (!jsonString || (id)kCFNull == jsonString) {return nil;}
    NSData *jsonData = [(NSString *)jsonString dataUsingEncoding: NSUTF8StringEncoding];
    return [self _xzh_modelFromJSONData:jsonData];
}

// NSData >>> NSDictionary
+ (instancetype)_xzh_modelFromJSONData:(NSData *)jsonData {
    if (!jsonData || (id)kCFNull == jsonData) {return nil;}
    NSDictionary *jsonDic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
    if (![jsonDic isKindOfClass:[NSDictionary class]]) {return nil;}
    return [self _xzh_modelFromJSONDictionary:jsonDic];
}

+ (instancetype)_xzh_modelFromJSONDictionary:(NSDictionary *)jsonDic {
    if (![jsonDic isKindOfClass:[NSDictionary class]]) {return nil;}
    
    // objc_class >>> ClassModel >>> ClassMapper
    XZHClassMapper *clsMapper = [XZHClassMapper classMapperWithClass:[self class]];
    if (!clsMapper) {return nil;}
    if (clsMapper->_mappedCount == 0) {return nil;}

    // 实例化一个实体类对象
    id model = [[self alloc] init];
    if (!model) {return nil;}
    
    // 组装参数集合Context实例
    XZHModelContext ctx = {0};
    ctx.modelSelf = (__bridge void*)(model);
    ctx.jsonDic = (__bridge void *)(jsonDic);
    ctx.classMapper = (__bridge void *)(clsMapper);
    
    // 判断json key count 与 mapped count
    if (jsonDic.count <= clsMapper->_mappedCount) {
        // 不需要遍历所有的PropertyMapper来解析json
        // 首先按照json dic.key 找到对应的PropertyMapper来解析json
        
        // 再按照keyPath PropertyMapper来解析json
        
        // 再按照keyArray PropertyMapper来解析json
    } else {
        
    }
    return model;
}

+ (instancetype)_xzh_modelFromJSONArray:(NSArray *)jsonArray {
    if ([jsonArray isKindOfClass:[NSArray class]]) {
        NSMutableArray *modelArray = [[NSMutableArray alloc] initWithCapacity:jsonArray.count];
        id model = nil;
        id json = nil;
        for (id jsonItem in jsonArray) {
            if ([jsonItem isKindOfClass:[NSString class]]) {
                json = [(NSString *)jsonItem dataUsingEncoding: NSUTF8StringEncoding];
            }
            if ([jsonItem isKindOfClass:[NSData class]]) {
                json = [NSJSONSerialization JSONObjectWithData:jsonItem options:kNilOptions error:NULL];
            }
            if ([jsonItem isKindOfClass:[NSDictionary class]]) {
                model = [self _xzh_modelFromJSONDictionary:jsonItem];
            }
        }
        if (model) {[modelArray addObject:model];}
    }
    return nil;
}

#pragma mark - Object To JSON

- (instancetype)xzh_modelToJSONObject {return nil;}
- (NSDictionary *)xzh_modelToJSONDictionary {return nil;}
- (instancetype)xzh_modelToJSONString {return nil;}
- (instancetype)xzh_modelToJSONData {return nil;}

@end

static xzh_force_inline NSDictionary* XZHJSONStringToDic(__unsafe_unretained NSString *jsonString) {
//    jsonString = XZHConvertNullNSString(jsonString);
    NSData* data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError* error = nil;
    id result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        return nil;
    } else {
        return result;
    }
}

static xzh_force_inline NSString* XZHConvertNullNSString(__unsafe_unretained id value) {
    if (!value || ![value isKindOfClass:[NSString class]]) return value;
    static NSDictionary *defaultDic = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultDic = @{
                       @"NIL" :    @"",
                       @"Nil" :    @"",
                       @"nil" :    @"",
                       @"NULL" :   @"",
                       @"Null" :   @"",
                       @"null" :   @"",
                       @"(NULL)" : @"",
                       @"(Null)" : @"",
                       @"(null)" : @"",
                       @"<NULL>" : @"",
                       @"<Null>" : @"",
                       @"<null>" : @"",
                       };
    });
    if (nil != [defaultDic objectForKey:value]) {
        return nil;
    }
    return value;
}

static xzh_force_inline NSNumber* XZHNumberWithValue(__unsafe_unretained id value) {
    static NSCharacterSet *dot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
    });
    if ([value isKindOfClass:[NSString class]]) {
        // true、false、yes、no 字符串类型
        static NSDictionary *defaultDic = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            defaultDic = @{
                           @"true" : @(1),
                           @"TRUE" : @(1),
                           @"True" : @(1),
                           @"false" : @(0),
                           @"FALSE" : @(0),
                           @"False" : @(0),
                           @"YES" : @(1),
                           @"yes" : @(1),
                           @"Yes" : @(1),
                           @"NO" : @(0),
                           @"no" : @(0),
                           @"No" : @(0),
                           };
        });
        id tmp = [defaultDic objectForKey:value];
        if (tmp) {return tmp;}
        
        // 数值类型的字符串
//        @try {
            if ([(NSString *)value rangeOfCharacterFromSet:dot].location != NSNotFound) {
                // 带小数的
                const char *cstring = ((NSString *)value).UTF8String;
                if (!cstring) return @(0);
                double num = atof(cstring);
                if (isnan(num) || isinf(num)) return @(0);//NaN、Inf默认返回0
                return @(num);
            } else {
                // 整数
                return @([value integerValue]);
            }
//        } @catch (NSException *exception) {
//            return @(0);
//        }
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return (NSNumber*)value;
    } else if (value == (id)kCFNull) {
        return nil;
    }
    return nil;
}

static xzh_force_inline NSNumber* XZHNumberWithModelProperty(__unsafe_unretained id object, __unsafe_unretained XZHPropertyMapper *mapper) {
    if (!object || !mapper) return nil;
    SEL getter = mapper->_property.getter;
    if (!getter) return nil;
    
    if (mapper->_isCNumber) {
        switch (mapper->_typeEncoding & XZHTypeEncodingDataTypeMask) {
            case XZHTypeEncodingChar: {//char、int8_t
                char num = ((char (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                return [NSNumber numberWithChar:num];
            }
                break;
            case XZHTypeEncodingUnsignedChar: {//unsigned char、uint8_t
                unsigned char num = ((unsigned char (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                return [NSNumber numberWithUnsignedChar:num];
            }
                break;
            case XZHTypeEncodingBOOL: {
                BOOL num = ((BOOL (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                return [NSNumber numberWithBool:num];
            }
                break;
            case XZHTypeEncodingShort: {//short、int16_t、
                short num = ((short (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                return [NSNumber numberWithShort:num];
            }
                break;
            case XZHTypeEncodingUnsignedShort: {//unsigned short、uint16_t、
                unsigned short num = ((unsigned short (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                return [NSNumber numberWithUnsignedShort:num];
            }
                break;
            case XZHTypeEncodingInt: {//int、int32_t、
                int num = ((int (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                return [NSNumber numberWithInt:num];
            }
                break;
            case XZHTypeEncodingUnsignedInt: {//unsigned int、uint32_t
                unsigned int num = ((unsigned int (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                return [NSNumber numberWithUnsignedInt:num];
            }
                break;
            case XZHTypeEncodingFloat: {
                float num = ((float (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                return [NSNumber numberWithFloat:num];
            }
                break;
            case XZHTypeEncodingLong32: {
                long num = ((long (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                if (isnan(num) || isinf(num)) return nil;
                return [NSNumber numberWithLong:num];
            }
                break;
            case XZHTypeEncodingLongLong: {
                long long num = ((long long (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                if (isnan(num) || isinf(num)) return nil;
                return [NSNumber numberWithLongLong:num];
            }
                break;
            case XZHTypeEncodingLongDouble: {
//                long double num = ((long double (*)(id, SEL))(void *) objc_msgSend)(object, getter); 使用double类型接收
                double num = ((long double (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                if (isnan(num) || isinf(num)) return nil;
                return @(num);
            }
                break;
            case XZHTypeEncodingUnsignedLong: {
                unsigned long num = ((unsigned long (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                if (isnan(num) || isinf(num)) return nil;
                return [NSNumber numberWithUnsignedLong:num];
            }
                break;
            case XZHTypeEncodingUnsignedLongLong: {
                unsigned long long num = ((unsigned long long (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                if (isnan(num) || isinf(num)) return nil;
                return [NSNumber numberWithUnsignedLongLong:num];
            }
                break;
            case XZHTypeEncodingDouble: {
                double num = ((double (*)(id, SEL))(void *) objc_msgSend)(object, getter);
                if (isnan(num) || isinf(num)) return nil;
                return [NSNumber numberWithDouble:num];
            }
                break;
        }
    } else if (mapper->_foundationType == XZHFoundationTypeNSNumber || mapper->_foundationType == XZHFoundationTypeNSDecimalNumber) {
        return ((NSNumber* (*)(id, SEL))(void *) objc_msgSend)(object, getter);
    } else if (mapper->_foundationType == XZHFoundationTypeNSString || mapper->_foundationType == XZHFoundationTypeNSMutableString) {
        NSString *value = ((NSString* (*)(id, SEL))(void *) objc_msgSend)(object, getter);
        return XZHNumberWithValue(value);
    }
    return nil;
}

static xzh_force_inline id XZHGetValueFromDictionaryWithMultiJSONKeyArray(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *keyArray) {
    if (!keyArray) {return nil;}
    if (![keyArray isKindOfClass:[NSArray class]]) {return nil;}
    id value = nil;
    for (id itemKey in keyArray) {
        if ([itemKey isKindOfClass:[NSString class]]) {
            //simple key
            if ([itemKey rangeOfString:@"."].location != NSNotFound) {
                @try {
                    value = [dic valueForKeyPath:itemKey];
                }
                @catch (NSException *exception) {
                    value = nil;
                }
            } else {
                value = [dic valueForKey:itemKey];
            }
        } else if ([itemKey isKindOfClass:[NSArray class]]) {
            //keypath没必要解析成数组形式，KVC可以valueForKeyPath:
        }
        
        if (value) {return value;}
    }
    return nil;
}

/*static xzh_force_inline id XZHDefaultFoundationObjectValueWithPropertyMapper(__unsafe_unretained id value, __unsafe_unretained XZHPropertyMapper *mapper) {
    //nil、[NSNull null] 处理
    if (!value || [value isKindOfClass:[NSNull class]]) {
        if (mapper->_isCNumber) {
            // 基本类型的数值
            value = @(0);
        } else {
            // Foundation Object
            switch (mapper->_foundationType) {
                case XZHFoundationTypeNSURL: {
//                    value = [NSURL URLWithString:@""];
                }
                    break;
                case XZHFoundationTypeNSArray: {
                    value = @[];
                }
                    break;
                case XZHFoundationTypeNSMutableArray: {
                    value = [NSMutableArray new];
                }
                    break;
                case XZHFoundationTypeNSSet: {
                    value = [NSSet set];
                }
                    break;
                case XZHFoundationTypeNSMutableSet: {
                    value = [NSMutableSet set];
                }
                    break;
                case XZHFoundationTypeNSDictionary: {
                    value = @{};
                }
                    break;
                case XZHFoundationTypeNSMutableDictionary: {
                    value = [NSMutableDictionary new];
                }
                    break;
                case XZHFoundationTypeNSNumber: {
                    value = @(0);
                }
                    break;
                case XZHFoundationTypeNSDecimalNumber: {
                    value = [NSDecimalNumber decimalNumberWithString:@"0"];
                }
                    break;
                case XZHFoundationTypeNSString: {
                    value = @"";
                }
                    break;
                case XZHFoundationTypeNSMutableString: {
                    value = [NSMutableString new];
                }
                    break;
                case XZHFoundationTypeCustomer: {
                    value = [mapper->_ivarClass new];
                }
                    break;
                case XZHFoundationTypeNSNull: {
                    value = [NSNull null];
                }
                    break;

                case XZHFoundationTypeUnKnown:
                case XZHFoundationTypeNSData:
                case XZHFoundationTypeNSMutableData:
                case XZHFoundationTypeNSDate:
                case XZHFoundationTypeNSValue:
                case XZHFoundationTypeNSBlock: {
                    // do nothing ...
                }
                    break;
            }
        }
    }
    
    // 如果是NSString对象，则单独做各种null的处理
    value = XZHConvertNullNSString(value);
    return value;
}*/

static xzh_force_inline id XZHGetValueFromDictionaryWithKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSString *keyPath) {
    if (!dic || ![dic isKindOfClass:[NSDictionary class]] || !keyPath || ![keyPath isKindOfClass:[NSString class]]) return nil;
    id value = nil;
    @try {
        value = [dic valueForKeyPath:keyPath];
    } @catch (NSException *exception) {
        value = nil;
    }
    return value;
}

/**
 *  只接收Foundation类型对象，(Class、Method、SEL、等CoreFoundation实例、c指针需要使用NSValue预先包装好)
 *  - 首先根据属性Ivar的类型分类
 *  - 再根据传入的jsonValue的类型，转换成属性Ivar的类型进行model对象设值
 *
 *  @param 只接受如下三种Foundation类型: 1)NSNumber 2)NSObject 3)NSValue
 *
 *      1. NSNumber:
 *          - BOOL
            - char/int8_t
            - unsigned char/uint8_t
            - int/int32_t
            - unsigned int/uint32_t
            - float
            - double
            - short/int16_t
            - unsigned short/uint16_t
            - long
            - unsigned long
            - long long/int64_t
            - unsigned long long/uint64_t
 
 *      2. Foundation Object
            - NSURL
            - NSArray/NSMutableArray
            - NSSet/NSMutableSet
            - NSDictionary/NSMutableDictionary
            - NSDate
            - NSData/NSMutableData
            - NSNumber/NSDecimalNumber
            - NSString/NSMutableString
            - NSValue
            - NSNull
            - NSBlock
            - 自定义继承自NSObject类

 *      3. c 指针类型/CoreFoundation实例
            - 1) c 指针类型（char*、int*....）
            - 2) CoreFoundation结构体实例（Class、Property、Ivar、SEL、Method....）
            - 3) 自定义struct/union/c array ===> 当做NSValue去存储
 
 *  @param object 实体类对象
 *  @param mapper 属性与jsonkey的映射关系
 */
static void XZHSetValueToProperty(__unsafe_unretained id value, __unsafe_unretained id object, __unsafe_unretained XZHPropertyMapper *mapper) {
    BOOL isSetterAccess = mapper->_isSetterAccess;
    if (!isSetterAccess) return;
    SEL setter = mapper->_property.setter;
    
    if (mapper->_isCNumber) {
        // 1. 数值类型 统一由NSNumber作为中转类型
        NSNumber *number = XZHNumberWithValue(value);
        if (!number || !mapper || [number isKindOfClass:[NSNull class]] || !object) return;
        if (mapper->_isCNumber) {
            switch (mapper->_typeEncoding & XZHTypeEncodingDataTypeMask) {
                case XZHTypeEncodingChar: {//char、int8_t
                    char num = [number charValue];
                    ((void (*)(id, SEL, char))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingUnsignedChar: {//unsigned char、uint8_t
                    unsigned char num = [number unsignedCharValue];
                    ((void (*)(id, SEL, unsigned char))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingBOOL: {
                    BOOL num = [number boolValue];
                    ((void (*)(id, SEL, BOOL))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingShort: {//short、int16_t、
                    short num = [number shortValue];
                    ((void (*)(id, SEL, short))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingUnsignedShort: {//unsigned short、uint16_t、
                    unsigned short num = [number shortValue];
                    ((void (*)(id, SEL, unsigned short))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingInt: {//int、int32_t、
                    int num = [number intValue];
                    ((void (*)(id, SEL, int))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingUnsignedInt: {//unsigned int、uint32_t
                    unsigned int num = [number unsignedIntValue];
                    ((void (*)(id, SEL, unsigned int))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingFloat: {
                    float num = [number floatValue];
                    ((void (*)(id, SEL, float))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingLong32: {
                    long num = [number longValue];
                    ((void (*)(id, SEL, long))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingLongLong: {
                    long long num = [number longLongValue];
                    ((void (*)(id, SEL, long long))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingLongDouble: {
                    long double num = [number doubleValue];
                    ((void (*)(id, SEL, long double))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingUnsignedLong: {
                    unsigned long num = [number unsignedLongValue];
                    ((void (*)(id, SEL, unsigned long))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingUnsignedLongLong: {
                    unsigned long long num = [number unsignedLongLongValue];
                    ((void (*)(id, SEL, unsigned long long))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                case XZHTypeEncodingDouble: {
                    double num = [number doubleValue];
                    ((void (*)(id, SEL, double))(void *) objc_msgSend)(object, setter, num);
                }
                    break;
                default:
                    break;
            }
        }
    } else if ((mapper->_typeEncoding & XZHTypeEncodingDataTypeMask) == XZHTypeEncodingFoundationObject){
        // 2. Foundation对象类型
        switch (mapper->_foundationType) {
            case XZHFoundationTypeNSURL: {
                // 1)NSURL 2)NSString
                if ([value isKindOfClass:[NSURL class]]) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)(object, setter, value);
                } else if ([value isKindOfClass:[NSString class]]) {
                    value = XZHConvertNullNSString(value);
                    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                    NSString *str = [value stringByTrimmingCharactersInSet:set];
                    if (str.length == 0) {
//                        ((void (*)(id, SEL, id))(void *) objc_msgSend)(object, setter, nil); 没必要
                    } else {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)(object, setter, [[NSURL alloc] initWithString:str]);
                    }
                }
            }
                break;
            case XZHFoundationTypeNSArray :
            case XZHFoundationTypeNSMutableArray: {
                // 1) NSArray 2)NSMutableArray 3) NSSet
                NSArray *valueArray = nil;
                if ([value isKindOfClass:[NSArray class]]) {valueArray = value;}
                else if ([value isKindOfClass:[NSSet class]]) {valueArray = [value allObjects];}
                if (mapper->_containerCls) {
                    // 解析array中每一个元素为实体对象，然后将解析的对象设置到model
                    if (valueArray) {
                        NSMutableArray *desArray = [[NSMutableArray alloc] initWithCapacity:valueArray.count];
                        for (id item in valueArray) {
                            if ([item isKindOfClass:mapper->_containerCls]) {//已经是指定类型
                                [desArray addObject:item];
                            } else if ([item isKindOfClass:[NSDictionary class]]) {//NSDictionary继续解析成实体对象
                                /**
                                 *  继续解析按照Class: 1)_containerCls指定的Class 2)实现xzh_classForDictionary:方法指定的class
                                 */
                                Class cls = mapper->_containerCls;
                                if ([mapper->_generacCls respondsToSelector:@selector(xzh_classForDictionary:)]) {
                                    cls = [(id<XZHJSONMappingConfig>)mapper->_generacCls xzh_classForDictionary:item];
                                }
                                
                                id newItem = [cls _xzh_modelFromJSONDictionary:item];
                                if (newItem)  {[desArray addObject:newItem];}
                            }
                        }
                        if (mapper->_foundationType == XZHFoundationTypeNSArray) {
                            ((void (*)(id, SEL, NSArray*))(void *) objc_msgSend)(object, setter, desArray.copy);
                        } else if (mapper->_foundationType == XZHFoundationTypeNSMutableArray) {
                            ((void (*)(id, SEL, NSMutableArray*))(void *) objc_msgSend)(object, setter, desArray);
                        }
                    }
                } else {
                    // 直接当NSArray对象设置到model
                    if (mapper->_foundationType == XZHFoundationTypeNSArray) {
                        ((void (*)(id, SEL, NSArray*))(void *) objc_msgSend)(object, setter, valueArray);
                    } else if (mapper->_foundationType == XZHFoundationTypeNSMutableArray) {
                        ((void (*)(id, SEL, NSMutableArray*))(void *) objc_msgSend)(object, setter, valueArray.mutableCopy);
                    }
                }
            }
                break;
            case XZHFoundationTypeNSSet:
            case XZHFoundationTypeNSMutableSet: {
                // 1) NSSet 2)NSMutableSet 3) NSArray
                NSSet *valueSet = nil;
                if ([value isKindOfClass:[NSSet class]]) {valueSet = value;}
                else if ([value isKindOfClass:[NSArray class]]) {valueSet = [NSSet setWithArray:value];}
                if (mapper->_containerCls) {
                    // 解析set中每一个元素为实体对象
                    if (valueSet) {
                        NSMutableSet *desSet = [[NSMutableSet alloc] initWithCapacity:valueSet.count];
                        for (id item in valueSet) {
                            if ([item isKindOfClass:mapper->_containerCls]) {
                                [desSet addObject:item];
                            } else if ([item isKindOfClass:[NSDictionary class]]) {
                                /**
                                 *  继续解析按照Class: 1)_containerCls指定的class 2)实现xzh_classForDictionary:方法指定的class
                                 */
                                Class cls = mapper->_containerCls;
                                if ([mapper->_generacCls respondsToSelector:@selector(xzh_classForDictionary:)]) {
                                    cls = [(id<XZHJSONMappingConfig>)mapper->_generacCls xzh_classForDictionary:item];
                                }
                                
                                id newItem = [mapper->_containerCls _xzh_modelFromJSONDictionary:item];
                                if (newItem) {[desSet addObject:newItem];}
                            }
                        }
                        if (mapper->_foundationType == XZHFoundationTypeNSSet) {
                            ((void (*)(id, SEL, NSSet*))(void *) objc_msgSend)(object, setter, desSet.copy);
                        } else if (mapper->_foundationType == XZHFoundationTypeNSMutableSet) {
                            ((void (*)(id, SEL, NSMutableSet*))(void *) objc_msgSend)(object, setter, desSet);
                        }
                    }
                } else {
                    if (mapper->_foundationType == XZHFoundationTypeNSSet) {
                        ((void (*)(id, SEL, NSSet*))(void *) objc_msgSend)(object, setter, valueSet);
                    } else if (mapper->_foundationType == XZHFoundationTypeNSMutableSet) {
                        ((void (*)(id, SEL, NSMutableSet*))(void *) objc_msgSend)(object, setter, valueSet.mutableCopy);
                    }
                }
            }
                break;
            case XZHFoundationTypeNSDictionary:
            case XZHFoundationTypeNSMutableDictionary: {
                // 1)NSDictionary 2)NSMutableDictionary
                NSDictionary *valueDic = nil;
                if ([value isKindOfClass:[NSDictionary class]]) {valueDic = value;}
                else if ([value isKindOfClass:[NSString class]]) {valueDic = XZHJSONStringToDic(value);}// 支持JSON字符串
                if (mapper->_containerCls) {
                    if (valueDic) {
                        // 解析dic中每一个key对应的value为实体对象
                        NSMutableDictionary *desDic = [[NSMutableDictionary alloc] initWithCapacity:valueDic.count];
                        [valueDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                            if ([obj isKindOfClass:mapper->_containerCls]) {
                                [desDic setObject:obj forKey:key];
                            } else if ([obj isKindOfClass:[NSDictionary class]]){
                                /**
                                 *  继续解析按照Class: 1)_containerCls指定的class 2)实现xzh_classForDictionary:方法指定的class
                                 */
                                Class cls = mapper->_containerCls;
                                if ([mapper->_generacCls respondsToSelector:@selector(xzh_classForDictionary:)]) {
                                    cls = [(id<XZHJSONMappingConfig>)mapper->_generacCls xzh_classForDictionary:obj];
                                }
                                
                                id newItem = [mapper->_containerCls _xzh_modelFromJSONDictionary:obj];
                                if (newItem) {[desDic setObject:newItem forKey:key];}
                            }
                        }];
                        if (mapper->_foundationType == XZHFoundationTypeNSDictionary) {
                            ((void (*)(id, SEL, NSDictionary*))(void *) objc_msgSend)(object, setter, desDic.copy);
                        } else if (mapper->_foundationType == XZHFoundationTypeNSMutableDictionary) {
                            ((void (*)(id, SEL, NSMutableDictionary*))(void *) objc_msgSend)(object, setter, desDic);
                        }
                    }
                } else {
                    if (mapper->_foundationType == XZHFoundationTypeNSDictionary) {
                        ((void (*)(id, SEL, NSDictionary*))(void *) objc_msgSend)(object, setter, valueDic);
                    } else if (mapper->_foundationType == XZHFoundationTypeNSMutableDictionary) {
                        ((void (*)(id, SEL, NSMutableDictionary*))(void *) objc_msgSend)(object, setter, valueDic.mutableCopy);
                    }
                }
            }
                break;
            case XZHFoundationTypeNSDate: {
                // 1)NSString（日期字符串） 2)NSDate 3) NSNumber
                if ([value isKindOfClass:[NSString class]]) {
                    value = XZHConvertNullNSString(value);
                    if ([mapper->_generacCls respondsToSelector:@selector(xzh_dateFormat)]) {
                        NSString *dateFormat = [mapper->_generacCls xzh_dateFormat];
                        if (dateFormat) {
                            NSDateFormatter *fomatter = XZHDateFormatter(dateFormat);
                            NSDate *date = [fomatter dateFromString:value];
                            if (date) {
                                ((void (*)(id, SEL, NSDate*))(void *) objc_msgSend)(object, setter, date);
                            }
                        }
                    }
                } else if ([value isKindOfClass:[NSNumber class]]) {
                    NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:[(NSNumber*)value doubleValue]];
                    if (date) {
                        ((void (*)(id, SEL, NSDate*))(void *) objc_msgSend)(object, setter, date);
                    }
                } else if ([value isKindOfClass:[NSDate class]]) {
                    ((void (*)(id, SEL, NSDate*))(void *) objc_msgSend)(object, setter, value);
                }
            }
                break;
            case XZHFoundationTypeNSData:
            case XZHFoundationTypeNSMutableData: {
                // 1)NSData 2)NSString
                if ([value isKindOfClass:[NSData class]]) {
                    if (mapper->_foundationType == XZHFoundationTypeNSData) {
                        ((void (*)(id, SEL, NSData*))(void *) objc_msgSend)(object, setter, value);
                    } else if (mapper->_foundationType == XZHFoundationTypeNSMutableData) {
                        NSData *data = (NSData*)value;
                        ((void (*)(id, SEL, NSData*))(void *) objc_msgSend)(object, setter, data.mutableCopy);
                    }

                } else if ([value isKindOfClass:[NSString class]]) {
                    value = XZHConvertNullNSString(value);
                    NSData *data = [(NSString*)value dataUsingEncoding:NSUTF8StringEncoding];
                    if (data) {
                        if (mapper->_foundationType == XZHFoundationTypeNSData) {
                            ((void (*)(id, SEL, NSData*))(void *) objc_msgSend)(object, setter, data);
                        } else if (mapper->_foundationType == XZHFoundationTypeNSMutableData) {
                            ((void (*)(id, SEL, NSData*))(void *) objc_msgSend)(object, setter, data.mutableCopy);
                        }
                    }
                }
            }
                break;
            case XZHFoundationTypeNSNumber:
            case XZHFoundationTypeNSDecimalNumber: {
                // 1)NSNumber 2)NSString（数值字符串/日期字符串） 3)NSDate
                if ([value isKindOfClass:[NSNumber class]]) {
                    ((void (*)(id, SEL, NSNumber*))(void *) objc_msgSend)(object, setter, value);
                } else if ([value isKindOfClass:[NSString class]]) {
                    value = XZHConvertNullNSString(value);
                    NSDate *date  = nil;
                    if ([mapper->_generacCls respondsToSelector:@selector(xzh_dateFormat)]) {
                        NSString *dateFormat = [mapper->_generacCls xzh_dateFormat];
                        if (dateFormat) {
                            NSDateFormatter *fomatter = XZHDateFormatter(dateFormat);
                            NSDate *date = [fomatter dateFromString:value];
                            if (date) {
                                ((void (*)(id, SEL, NSDate*))(void *) objc_msgSend)(object, setter, date);
                            }
                        }
                    }
                    NSNumber *number = nil;
                    if (date) {
                        number = [NSNumber numberWithDouble:[date timeIntervalSinceReferenceDate]];
                    } else {
                        number = XZHNumberWithValue(value);
                    }
                    ((void (*)(id, SEL, NSNumber*))(void *) objc_msgSend)(object, setter, number);
                } else if ([value isKindOfClass:[NSDate class]]) {
                    NSNumber *number = [NSNumber numberWithDouble:[(NSDate*)value timeIntervalSinceReferenceDate]];
                    if (number) {
                        ((void (*)(id, SEL, NSNumber*))(void *) objc_msgSend)(object, setter, number);
                    }
                }
            }
                break;
            case XZHFoundationTypeNSString:
            case XZHFoundationTypeNSMutableString: {
                //1) NSString 2)NSMutableString 3)NSDate 4)NSNumber 5)NSData 6)NSURL
                if ([value isKindOfClass:[NSString class]]) {
                    value = XZHConvertNullNSString(value);
                    if (mapper->_foundationType == XZHFoundationTypeNSString) {
                        ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, value);
                    } else if (mapper->_foundationType == XZHFoundationTypeNSMutableString) {
                        ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, value);
                    }
                } else if ([value isKindOfClass:[NSDate class]]) {
                    if ([mapper->_generacCls respondsToSelector:@selector(xzh_dateFormat)]) {
                        NSString *dateFormat = [mapper->_generacCls xzh_dateFormat];
                        if (dateFormat) {
                            NSDateFormatter *fomatter = XZHDateFormatter(dateFormat);
                            NSString *dateStr = [fomatter stringFromDate:value];
                            if (dateStr) {
                                if (mapper->_foundationType == XZHFoundationTypeNSString) {
                                    ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, dateStr);
                                } else if (mapper->_foundationType == XZHFoundationTypeNSMutableString) {
                                    ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, dateStr.mutableCopy);
                                }
                            }
                        }
                    }
                } else if ([value isKindOfClass:[NSNumber class]]) {
                    NSString *valueString = [(NSNumber*)value stringValue];
                    if (valueString) {
                        if (mapper->_foundationType == XZHFoundationTypeNSString) {
                            ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, valueString);
                        } else if (mapper->_foundationType == XZHFoundationTypeNSMutableString) {
                            ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, valueString.mutableCopy);
                        }
                    }
                } else if ([value isKindOfClass:[NSData class]]) {
                    NSString *valueString = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                    if (valueString) {
                        if (mapper->_foundationType == XZHFoundationTypeNSString) {
                            ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, valueString);
                        } else if (mapper->_foundationType == XZHFoundationTypeNSMutableString) {
                            ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, valueString.mutableCopy);
                        }
                    }
                } else if ([value isKindOfClass:[NSURL class]]) {
                    NSString *valueString = [(NSURL*)value absoluteString];
                    if (valueString) {
                        if (mapper->_foundationType == XZHFoundationTypeNSString) {
                            ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, valueString);
                        } else if (mapper->_foundationType == XZHFoundationTypeNSMutableString) {
                            ((void (*)(id, SEL, NSString*))(void *) objc_msgSend)(object, setter, valueString.mutableCopy);
                        }
                    }
                }
            }
                break;
            case XZHFoundationTypeNSValue: {
                if ([value isKindOfClass:[NSValue class]]) {
                    ((void (*)(id, SEL, NSValue*))(void *) objc_msgSend)(object, setter, value);
                }
            }
                break;
            case XZHFoundationTypeNSNull: {
                if ([value isKindOfClass:[NSNull class]]) {
                    ((void (*)(id, SEL, NSNull*))(void *) objc_msgSend)(object, setter, (id)kCFNull);
                }
            }
                break;
            case XZHFoundationTypeNSBlock: {
                if ([value isKindOfClass:XZHGetNSBlockClass()]) {
                    // NSBlock的任意类: void(^)()，其实任意参数的block都可以设置进去，只是取出来执行的时候需要看参数类型
                    ((void (*)(id, SEL, void(^)()))(void *) objc_msgSend)(object, setter, value);
                }
            }
                break;
            case XZHFoundationTypeCustomer: {
                //1)自定义NSObject类型 2)NSDictionary 3)NSString
                if ([value isKindOfClass:mapper->_ivarClass]) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)(object, setter, value);
                } else if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSString class]]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        value = XZHConvertNullNSString(value);
                        value = XZHJSONStringToDic(value);
                    }
                    Class cls = mapper->_ivarClass;
                    if([mapper->_generacCls respondsToSelector:@selector(xzh_classForDictionary:)]) {
                        cls = [mapper->_generacCls xzh_classForDictionary:value];
                    }
                    id valueObject = [cls _xzh_modelFromJSONDictionary:value];
                    if (valueObject) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)(object, setter, valueObject);
                    }
                }
            }
                break;
            case  XZHFoundationTypeUnKnown : {
                // do nothings ...
            }
                break;
        }
    } else {
        // 3. c复杂类型
        switch (mapper->_typeEncoding & XZHTypeEncodingDataTypeMask) {
            case XZHTypeEncodingCString:
            case XZHTypeEncodingCPointer: {//char*、int*、float*....等等基本类型指针统一按照 void* 处理，NSValue包装时也是默认转成void*
                // 1)NSValue包裹: char*、int*、float*....等等基本类型指针
                if (value == (id)kCFNull) {
                    ((void (*)(id, SEL, void*))(void *) objc_msgSend)(object, setter, (void*)NULL);
                } else {
                    if ([value isKindOfClass:[NSValue class]]) {
                        NSValue *nsvalue = (NSValue *)value;
                        if (nsvalue.objCType && 0 == strcmp(nsvalue.objCType, "^v")) {//void*
                            ((void (*)(id, SEL, void*))(void *) objc_msgSend)(object, setter, nsvalue.pointerValue);
                        }
                    }
                }
            }
                break;
            case XZHTypeEncodingObjcClass: {
                //1)NSString 2)实体类对象 3)NSvalue包裹: char*
                if (value == (id)kCFNull) {
                    ((void (*)(id, SEL, Class))(void *) objc_msgSend)(object, setter, (Class)NULL);
                } else {
                    if ([value isKindOfClass:[NSString class]]) {
                        Class cls = NSClassFromString(value);
                        if (cls) {
                            ((void (*)(id, SEL, Class))(void *) objc_msgSend)(object, setter, cls);
                        }
                    } else if ([value isKindOfClass:[NSValue class]]) {
                        //objc_getClass()
                        NSValue *nsvalue = (NSValue *)value;
                        if (nsvalue.objCType && 0 == strcmp(nsvalue.objCType, "^v")) {
                            char *clsName = (char *)nsvalue.pointerValue;
                            if (NULL != clsName) {
                                Class cls = objc_getClass(clsName);
                                if (cls) {
                                    ((void (*)(id, SEL, Class))(void *) objc_msgSend)(object, setter, cls);
                                }
                            }
                        }
                    } else {
                        //object_getClass()
                        Class cls = object_getClass(value);
                        if (cls) {
                            ((void (*)(id, SEL, Class))(void *) objc_msgSend)(object, setter, cls);
                        }
                    }
                }
            }
                break;
            case XZHTypeEncodingSEL: {
                //1)NSString 2)NSvalue包裹: char*
                if (value == (id)kCFNull) {
                    ((void (*)(id, SEL, SEL))(void *) objc_msgSend)(object, setter, (SEL)NULL);
                } else if ([value isKindOfClass:[NSString class]]){
                    SEL sel = NSSelectorFromString(value);
                    if (sel) {
                        ((void (*)(id, SEL, SEL))(void *) objc_msgSend)(object, setter, sel);
                    }
                } else if ([value isKindOfClass:[NSValue class]]) {
                    NSValue *nsvalue = (NSValue *)value;
                    if (nsvalue.objCType && strcmp(nsvalue.objCType, "^v")) {
                        char *selC = (char *)nsvalue.pointerValue;
                        if (selC) {
                            NSString *selF = [NSString stringWithUTF8String:selC];
                            SEL sel = NSSelectorFromString(selF);
                            if (sel) {
                                ((void (*)(id, SEL, SEL))(void *) objc_msgSend)(object, setter, sel);
                            }
                        }
                    }
                }
            }
                break;
            case XZHTypeEncodingCArray:
            case XZHTypeEncodingCStruct:
            case XZHTypeEncodingCUnion: {//当做NSValue存储
                if (value == (id)kCFNull) {
                    ((void (*)(id, SEL, SEL))(void *) objc_msgSend)(object, setter, (SEL)NULL);
                } else if ([value isKindOfClass:[NSValue class]]) {
                    NSValue *nsvalue = (NSValue *)value;
                    const char *nsvalueCoding = nsvalue.objCType;
                    const char *propertyModelCoding = mapper->_typeEncodingString.UTF8String;
                    if (nsvalueCoding && propertyModelCoding && 0 == strcmp(nsvalueCoding, propertyModelCoding)) {
                        ((void (*)(id, SEL, NSValue*))(void *) objc_msgSend)(object, setter, nsvalue);
                    }
                }
            }
                break;
        }
    }
}

static xzh_force_inline NSArray* XZHGetPropertyMultiJSONKeyArray(__unsafe_unretained NSArray *keyArr) {
    if (!keyArr) return nil;
    NSMutableArray *parsedKeyArr = [[NSMutableArray alloc] initWithCapacity:keyArr.count];
    for (NSString *item in keyArr) {
        if ([item isKindOfClass:[NSString class]]) {
            if ([item rangeOfString:@"."].location != NSNotFound) {
                //keypath
                NSArray *keypath = [item componentsSeparatedByString:@"."];
                if (keypath) {[parsedKeyArr addObject:keypath];}
            } else {
                //key
                [parsedKeyArr addObject:item];
            }
        } else if ([item isKindOfClass:[NSArray class]]) {
            //array
            NSArray *subArray = XZHGetPropertyMultiJSONKeyArray((NSArray*)item);
            if (subArray) {[parsedKeyArr addObject:subArray];}
        }
    }
    return [parsedKeyArr copy];
}

static void XZHModelCFDictionaryApplierFunction(const void *key, const void *value, void *context) {
    if (NULL == value || NULL == context) {return;}
    
    /**
     *  使用 __unsafe_unretained 修饰OC对象指针，减少runtime system自动进行retain操作影响代码运行速度
     *  因为jsonDic、classMapper、propertyMapper、model都是由Context结构体实例持有
     *  所以不必担心jsonDic、classMapper、propertyMapper、model 这些对象会被废弃的问题
     */
    XZHModelContext *ctx = (XZHModelContext *)context;
    
    __unsafe_unretained NSDictionary *jsonDic = (__bridge NSDictionary *)(ctx->jsonDic);// json在调用这个函数地方被持有，此处不需要对其进行持有
    if (!jsonDic || ![jsonDic isKindOfClass:[NSDictionary class]]) return;
    
    //    __unsafe_unretained XZHClassMapper *clsMapper = (__bridge XZHClassMapper*)(ctx->classMapper);
    //    if (!clsMapper || clsMapper->_mappedCount < 1) {return;}
    
    __unsafe_unretained XZHPropertyMapper *propertyMapper = (__bridge XZHPropertyMapper*)(value);// XZHPropertyMapper对象被ClassMapper对象所持有，此处不需要对其进行持有
    while (propertyMapper) {// n 属性:1 jsonkey
        // 取出json value
        id jsonValue;
        
        if (propertyMapper->_mappedToSimpleKey) {
            jsonValue = [jsonDic objectForKey:propertyMapper->_mappedToSimpleKey];
        } else if (propertyMapper->_mappedToKeyPath) {
            //            @try {
            //                jsonValue = [jsonDic valueForKeyPath:propertyMapper->_mappedToKeyPath];
            //            }
            //            @catch (NSException *exception) {
            //                jsonValue = nil;
            //            }
        } else {
            //            jsonValue = XZHGetValueFromDictionaryWithMultiJSONKeyArray(jsonDic, propertyMapper->_mappedToKeyArray);
        }
        
        // 对取出的json value做预处理
        if (jsonValue == (id)kCFNull) {jsonValue = nil;}
        if (jsonValue) {
            __unsafe_unretained id modelSelf = (__bridge id)(ctx->modelSelf);
            if (!modelSelf || (id)kCFNull == modelSelf) {return;}
            //            XZHSetValueToProperty(jsonValue, modelSelf, propertyMapper);
        }
        propertyMapper = propertyMapper->_next;
    }
}

static void XZHModelSimpleKeyCFArrayApplierFunction(const void *value, void *context) {
    if (NULL == value || NULL == context) {return;}
    
    XZHModelContext *ctx = (XZHModelContext *)context;
    __unsafe_unretained NSDictionary *jsonDic = (__bridge NSDictionary *)(ctx->jsonDic);
    if (!jsonDic || ![jsonDic isKindOfClass:[NSDictionary class]]) return;
    
//    __unsafe_unretained XZHClassMapper *clsMapper = (__bridge XZHClassMapper*)(ctx->classMapper);
//    if (!clsMapper || clsMapper->_mappedCount < 1) {return;}
    
    __unsafe_unretained XZHPropertyMapper *propertyMapper = (__bridge XZHPropertyMapper*)(value);
    while (propertyMapper) {
        id jsonValue = [jsonDic objectForKey:propertyMapper->_mappedToSimpleKey];
//        if (jsonValue == (id)kCFNull) {jsonValue = nil;}
//        if (jsonValue) {
//            __unsafe_unretained id modelSelf = (__bridge id)(ctx->modelSelf);
//            if (!modelSelf || (id)kCFNull == modelSelf) {return;}
//                        XZHSetValueToProperty(jsonValue, modelSelf, propertyMapper);
//        }
        propertyMapper = propertyMapper->_next;

    }
}

static void XZHModelKeyPathCFArrayApplierFunction(const void *value, void *context) {
    
}

static void XZHModelKeyArrayCFArrayApplierFunction(const void *value, void *context) {
    
}

static xzh_force_inline NSDateFormatter* XZHDateFormatter(__unsafe_unretained NSString *dateFormat) {
    if (!dateFormat) return nil;
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    });
    formatter.dateFormat = dateFormat;
    return formatter;
}

