//
//  MessageListController.swift
//  GridImageView
//
//  Created by Rajat Dhasmana on 07/01/26.
//

import Foundation
import UIKit
import SwiftUI
import Combine


final class MessageListController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.backgroundColor = .clear
        view.backgroundColor = .clear
        setupViews()
        setupMessageListeners()
        
    }
    
    init(viewModel: ChatViewModel) {
        
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        subscriptions.forEach({ $0.cancel() })
        subscriptions.removeAll()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder) not implemented")
    }
    
    
    private let viewModel: ChatViewModel
    private var subscriptions = Set<AnyCancellable>()
    
    private let cellIdentifier = "MessageListControllerCells"
    
    private var lastScrollPosition: UUID?
    
    private let compositionalLayout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
        
        var listConfig = UICollectionLayoutListConfiguration(appearance: .plain)
        listConfig.backgroundColor = UIColor.gray.withAlphaComponent(0.2)
        listConfig.showsSeparators = false
        let section = NSCollectionLayoutSection.list(using: listConfig, layoutEnvironment: layoutEnvironment)
        section.contentInsets.leading = 0
        section.contentInsets.trailing = 0
        section.interGroupSpacing = 0
        return section
    }
    
    
    private lazy var messagesCollectionView: UICollectionView = {
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: compositionalLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.selfSizingInvalidation = .enabledIncludingConstraints
        collectionView.contentInset = .init(top: 0, left: 0, bottom: 60, right: 0)
        collectionView.scrollIndicatorInsets = .init(top: 0, left: 0, bottom: 60, right: 0)
        collectionView.keyboardDismissMode = .onDrag
        collectionView.backgroundColor = .clear
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        return collectionView
    }()
    
    
    private let backgroundImageView: UIImageView = {
        
        let backgroundImageView = UIImageView(image: .dummy)
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        return backgroundImageView
    }()
    
    private func setupViews() {
        
//        view.addSubview(backgroundImageView)
        view.addSubview(messagesCollectionView)
        
        
        NSLayoutConstraint.activate([
//            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
//            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            messagesCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            messagesCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            messagesCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            messagesCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            
        ])
    }
    
    private func setupMessageListeners() {
        
        let delay = 200
        viewModel.$messages
            .debounce(for: .milliseconds(delay), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.messagesCollectionView.reloadData()
                print("received subscription message count -> \(self?.viewModel.messages.count)")
            }.store(in: &subscriptions)
        
//        viewModel.$scrollPosition
//            .debounce(for: .milliseconds(delay), scheduler: DispatchQueue.main)
//            .sink { [weak self] scrollPosition in
//                
//                if let scrollPosition {
//                    self?.messagesCollectionView.scrollToLastItem(scrollPosition: .bottom, animated: scrollPosition.animated)
//                }
//            }.store(in: &subscriptions)
        
        
        
        
//        viewModel.$isPaginating
//            .debounce(for: .milliseconds(delay), scheduler: DispatchQueue.main)
//            .sink { [weak self] isPaginating in
//                
//                guard let self, let lastScrollPosition else { return }
//                
//                if !isPaginating {
//                    
//                    guard let index = viewModel.messages.firstIndex(where: { $0.id == lastScrollPosition }) else { return }
//                    
//                    let indexPath = IndexPath(item: index, section: 0)
//                    self.messagesCollectionView.scrollToItem(at: indexPath, at: .top, animated: false)
//                }
//                
//            }.store(in: &subscriptions)

        
        viewModel.$scrollPosition
            .debounce(for: .milliseconds(delay), scheduler: DispatchQueue.main)
            .sink { [weak self] scrollPosition in
                
                guard let self else { return }
//                
//                lastScrollPosition = scrollPosition?.id
//                guard let index = viewModel.messages.firstIndex(where: { $0.id == self.lastScrollPosition }) else { return }
//                
//                let indexPath = IndexPath(item: index, section: 0)
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                    
//                    self.messagesCollectionView.scrollToItem(at: indexPath, at: .top, animated: false)
//
//                }


                
                
                
                if let scrollPosition {
                    guard let index = self.viewModel.messages.firstIndex(where: { $0.id == scrollPosition.id }) else { return }

                    let indexPath = IndexPath(item: index, section: 0)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        
                        self.messagesCollectionView.scrollToItem(at: indexPath, at: .top, animated: false)
                    }

                }
                
            }.store(in: &subscriptions)

    }
    
    @objc private func refreshData() {
        
        lastScrollPosition = viewModel.messages.first?.id
    }
}

extension MessageListController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.messages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
        
        cell.backgroundColor = .clear
        let message = viewModel.messages[indexPath.item]
        
        cell.contentConfiguration = UIHostingConfiguration {
            
            Text(message.text)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .id(message.id)
//                .onAppear {
//                    
//                    if message == self.viewModel.messages.first {
//                        
//                        Task {
//                            self.lastScrollPosition = message.id
//                            self.viewModel.scrollPosition = ScrollPositionModel(id: message.id, position: .bottom)
//                            await self.viewModel.loadMoreMessages()
//                        }
//                    }
//                }
        }
        return cell
    }
    
//    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        
//        let messageItem = viewModel.messages[indexPath.row]
//        
//
//    }
    
    
    
    
}

private extension UICollectionView {
    
    func scrollToLastItem(scrollPosition: UICollectionView.ScrollPosition, animated: Bool) {
        
        guard numberOfItems(inSection: numberOfSections - 1) > 0 else { return }
        let lastSectionIndex = numberOfSections - 1
        let lastRowIndex = numberOfItems(inSection: lastSectionIndex) - 1
        let lastRowIndexPath = IndexPath(row: lastRowIndex, section: lastSectionIndex)
        
        scrollToItem(at: lastRowIndexPath, at: scrollPosition, animated: animated)
    }
}



struct MessageListView: UIViewControllerRepresentable {
    
    private var chatViewModel: ChatViewModel
    
    init(chatViewModel: ChatViewModel) {
        self.chatViewModel = chatViewModel
    }
    
    func makeUIViewController(context: Context) -> some MessageListController {
        let messageListController = MessageListController(viewModel: chatViewModel)
        return messageListController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    
}
