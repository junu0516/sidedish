import Foundation

final class Repository: RepositoryApplicable {
    
    weak var delegate: RepositoryDelegate?
    private let jsonHandler: JSONHandlable
    private var networkHandler: NetworkHandlable
    private let dataCache: DataCachingManagable
    
    convenience init(){
        self.init(networkHandler: NetworkHandler(), jsonHandler: JSONHandler(), dataCache: DataCachingManager())
    }
    
    init(networkHandler: NetworkHandlable, jsonHandler: JSONHandlable, dataCache: DataCachingManagable){
        self.networkHandler = networkHandler
        self.jsonHandler = jsonHandler
        self.dataCache = dataCache
        
        self.networkHandler.delegate = self
    }
    
    func fetchBackgroundData<T: Codable>(category: Category, dataType: T.Type) {
        guard let data = getSampleJSONData(fileName: category.fileName) else { return }
        guard let response = jsonHandler.convertJSONToObject(from: data, to: MainResponse<T>.self) else { return }
        for backgroundData in response.body {
            delegate?.fetchBackgroundData(category: category, backgroundData: backgroundData)
        }
    }
    
    private func getSampleJSONData(fileName: String) -> Data? {
        guard let path = Bundle.main.url(forResource: fileName, withExtension: "json") else { return nil }
        guard let data: Data = try? Data(contentsOf: path) else { return nil }
        return data
    }
    
    func requestBinaryData(method: HttpMethod, contentType: ContentType, url: EndPoint, completionHandler: @escaping (Result<Data,Error>) -> Void){
        if let binaryData = dataCache.getCacheData(key: url.urlString){
            completionHandler(.success(binaryData))
        }else{
            networkHandler.request(url: url, method: method, contentType: contentType, completionHandler: completionHandler)
        }
    }
    
    func requestModelData<T: Codable>(method: HttpMethod, contentType: ContentType, url: EndPoint, completionHandler: @escaping (Result<T,Error>) -> Void){
        if let jsonData = dataCache.getCacheData(key: url.urlString){
            guard let model = jsonHandler.convertJSONToObject(from: jsonData, to: T.self) else { return }
            completionHandler(.success(model))
        }else{
            networkHandler.request(url: url, method: method, contentType: contentType) { result in
                switch result{
                case .success(let data):
                    guard let model = self.jsonHandler.convertJSONToObject(from: data, to: T.self) else { return }
                    completionHandler(.success(model))
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        }
    }
}

extension Repository: NetworkHandlerDelegate {
    func cachingDataRequested(url: EndPoint, data: Data) {
        dataCache.addCacheData(data: data, key: url.urlString)
    }
}
