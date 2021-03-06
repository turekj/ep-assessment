import Cartography
import RxCocoa
import RxSwift
import UIKit


class UserRepositoryViewController: UIViewController, UserRepositoryList {
    
    let userRepositoryView: UserRepositoryView
    let userRepositoryService: AnySearchService<UserRepository>
    let rateLimitErrorDetector: ErrorDetector
    
    var onUserRepositorySelected: ((UserRepository) -> Void)?
    
    var navigationBarTitle = ""
    var translucentNavigationBar = false
    
    var searchResults: Observable<[UserRepository]> = Observable.just([])
    let disposeBag = DisposeBag()
    
    init(view: UserRepositoryView, userRepositoryService: AnySearchService<UserRepository>,
         rateLimitErrorDetector: ErrorDetector) {
        self.userRepositoryView = view
        self.userRepositoryService = userRepositoryService
        self.rateLimitErrorDetector = rateLimitErrorDetector
        
        super.init(nibName: nil, bundle: nil)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureView()
        self.bindViewModel()
    }
    
    func configureView() {
        self.view.addSubview(self.userRepositoryView)
        
        constrain(self.userRepositoryView) { v in
            v.edges == v.superview!.edges
        }
    }
    
    func bindViewModel() {
        self.searchResults = self.userRepositoryView.searchBar.rx.text
            .throttle(0.3, scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .flatMapLatest { query -> Observable<[UserRepository]> in
                guard query.characters.count > 1 else {
                    return .just([])
                }
                
                return self.userRepositoryService.search(withQuery: query)
                    .map { $0.sorted(by: { $0.id < $1.id }) }
                    .catchError { error in
                        if (self.rateLimitErrorDetector.isDomainSpecificError(error: error)) {
                            self.userRepositoryView.presentToast(
                                "Rate limit hit. You are too fast! 🔥")
                        }
                        
                        return Observable.just([])
                    }
            }
            .observeOn(MainScheduler.instance)
        
        self.searchResults
            .bindTo(self.userRepositoryView.list.rx.items(
                    cellIdentifier: ReuseIdentifiers.userRepositoryCell.rawValue,
                    cellType: UserRepositoryCell.self)) { (row, userRepository, cell) in
                cell.titleView.text = userRepository.title
                cell.subtitleView.text = userRepository.url
            }
            .addDisposableTo(self.disposeBag)
        
        self.userRepositoryView.list.rx.modelSelected(UserRepository.self)
            .asDriver()
            .drive(onNext: { userRepository in
                self.onUserRepositorySelected?(userRepository)
            })
            .addDisposableTo(self.disposeBag)
    }
    
    // MARK: - Layout
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.navigationController?.navigationBar.isTranslucent = self.translucentNavigationBar
        self.navigationItem.title = self.navigationBarTitle
    }
    
    // MARK: - Required init
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
