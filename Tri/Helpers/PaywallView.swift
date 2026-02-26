//
//  PaywallView.swift
//  Tri
//
//  Created by Ben Stacy on 2/25/26.
//

import SwiftUI
import StoreKit

struct PaywallView<Header: View, Links: View, Loader: View>: View {
    var isCompact: Bool
    var ids: [String]
    var points: [PaywallPoint]
    @ViewBuilder var header: Header
    @ViewBuilder var links: Links
    @ViewBuilder var loadingView: Loader
    @State private var isLoaded: Bool = false
    var body: some View {
        SubscriptionStoreView(productIDs: ids, marketingContent: {
            MarketingContent()
        })
        .subscriptionStoreControlStyle(CustomSubscriptionStyle(isCompact: isCompact, links: {
            links
        }, isLoaded: {
            isLoaded = true
        }), placement: .scrollView)
        .storeButton(.hidden, for: .policies)
        .storeButton(.visible, for: .restorePurchases)
        .animation(.easeInOut(duration: 0.35)) { content in
            content
                .opacity(isLoaded ? 1 : 0)
        }
        .overlay {
            ZStack {
                if !isLoaded {
                    loadingView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: isLoaded)
        }
        /// Optional Scroll Properties
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
    }
    
    /// Custom Marketing Content View
    @ViewBuilder
    func MarketingContent() -> some View {
        VStack(spacing: 15) {
            header
            
            if isLoaded {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(points.indices, id: \.self) { index in
                        let point = points[index]
                        
                        AnimatedPointView(index: index, point: point)
                    }
                }
                .transition(.identity)
            }
            
            Spacer(minLength: 0)
        }
        .padding([.horizontal, .top], 15)
    }
}

fileprivate struct AnimatedPointView: View {
    var index: Int
    var point: PaywallPoint
    /// View Properties
    @State private var animateSymbol: Bool = false
    @State private var animateContent: Bool = false
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if animateSymbol {
                    Image(systemName: point.symbol)
                        .font(.title2)
                        .symbolVariant(.fill)
                        .foregroundStyle(point.symbolTint)
                        .transition(.blurReplace)
                }
            }
            .frame(width: 35, height: 35)
            
            Text(point.content)
                .font(.callout)
                .fontWeight(.medium)
                .padding(.leading, 10)
                .foregroundStyle(Color.primary)
                .visualEffect({ [animateContent] content, proxy in
                    content
                        .opacity(animateContent ? 1 : 0)
                        .offset(x: animateContent ? 0 : -proxy.size.width)
                })
                .clipped()
            
            Spacer(minLength: 0)
        }
        .task {
            /// Index Based Delay to show one after another
            guard !animateSymbol else { return }
            try? await Task.sleep(for: .seconds(Double(index) * 0.4))
            withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                animateSymbol = true
            }
            
            try? await Task.sleep(for: .seconds(Double(index) * 0.11))
            withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                animateContent = true
            }
        }
    }
}

fileprivate struct CustomSubscriptionStyle<Links: View>: SubscriptionStoreControlStyle {
    var isCompact: Bool
    @ViewBuilder var links: Links
    var isLoaded: () -> ()
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 10) {
            VStack(spacing: 25) {
                if isCompact {
                    CompactPickerSubscriptionStoreControlStyle().makeBody(configuration: configuration)
                } else {
                    PagedProminentPickerSubscriptionStoreControlStyle().makeBody(configuration: configuration)
                }
            }
            
            /// Links
            links
                .buttonStyle(.plain)
                .padding(.vertical, isiOS26 ? 0 : 5)
        }
        .onAppear(perform: isLoaded)
        .offset(y: 12)
    }
    
    var isiOS26: Bool {
        if #available(iOS 26, *) {
            return true
        }
        
        return false
    }
}

/// Paywall Point Model
struct PaywallPoint: Identifiable {
    var id: String = UUID().uuidString
    var symbol: String
    var symbolTint: Color = .primary
    var content: String
}
