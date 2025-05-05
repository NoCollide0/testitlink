import SwiftUI

struct ImageDetailView: View {
    @ObservedObject var presenter: ImageDetailPresenter
    @StateObject private var viewModel = ImageViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.presentationMode) private var presentationMode //Кнопка назад
    
    //Жесты
    @GestureState private var dragOffset: CGSize = .zero
    @State private var offset: CGFloat = 0
    @State private var draggingOffset: CGFloat = 0
    
    //Для перемещения при увеличении
    @State private var imageOffset: CGSize = .zero
    
    //Для принудительного обновления предпросмотра
    @State private var previewUpdateCounter = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                
                if let image = viewModel.image {
                    ZStack {
                        //Предыдущее изображение (для анимации перелистывания)
                        if presenter.scale <= 1.0 && presenter.imageURLs.count > 1 {
                            let prevIndex = (presenter.currentImageIndex - 1 + presenter.imageURLs.count) % presenter.imageURLs.count
                            PreviousImageView(
                                imageURL: presenter.imageURLs[prevIndex],
                                currentIndex: presenter.currentImageIndex,
                                updateCounter: previewUpdateCounter,
                                geometry: geometry
                            )
                            .opacity(draggingOffset > 0 ? min(draggingOffset / 100, 0.8) : 0)
                            .offset(x: -geometry.size.width + draggingOffset)
                        }
                        
                        //Текущее изображение
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(presenter.scale)
                            .offset(x: presenter.scale <= 1.0 ? draggingOffset : imageOffset.width + dragOffset.width, 
                                    y: presenter.scale <= 1.0 ? 0 : imageOffset.height + dragOffset.height)
                            .gesture(
                                DragGesture()
                                    .updating($dragOffset) { value, state, _ in
                                        //Если изображение увеличено, разрешаем свободное перемещение
                                        if presenter.scale > 1.0 {
                                            state = value.translation
                                        }
                                    }
                                    .onChanged { value in
                                        //Если изображение не увеличено, двигаемся только по оси X
                                        if presenter.scale <= 1.0 {
                                            draggingOffset = value.translation.width
                                        }
                                    }
                                    .onEnded { value in
                                        if presenter.scale > 1.0 {
                                            imageOffset.width += value.translation.width
                                            imageOffset.height += value.translation.height
                                            
                                            let maxOffset = (presenter.scale - 1.0) * geometry.size.width / 2
                                            imageOffset.width = min(maxOffset, max(-maxOffset, imageOffset.width))
                                            
                                            let maxOffsetHeight = (presenter.scale - 1.0) * geometry.size.height / 2
                                            imageOffset.height = min(maxOffsetHeight, max(-maxOffsetHeight, imageOffset.height))
                                        } else {
                                            let threshold: CGFloat = 80
                                            
                                            withAnimation(.spring()) {
                                                if draggingOffset > threshold {
                                                    presenter.previousImage()
                                                    previewUpdateCounter += 1
                                                } else if draggingOffset < -threshold {
                                                    presenter.nextImage()
                                                    previewUpdateCounter += 1
                                                }
                                                draggingOffset = 0
                                            }
                                        }
                                    }
                            )
                        
                        if presenter.scale <= 1.0 && presenter.imageURLs.count > 1 {
                            let nextIndex = (presenter.currentImageIndex + 1) % presenter.imageURLs.count
                            NextImageView(
                                imageURL: presenter.imageURLs[nextIndex],
                                currentIndex: presenter.currentImageIndex,
                                updateCounter: previewUpdateCounter,
                                geometry: geometry
                            )
                            .opacity(draggingOffset < 0 ? min(-draggingOffset / 100, 0.8) : 0)
                            .offset(x: geometry.size.width + draggingOffset)
                        }
                    }
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / presenter.lastScaleValue
                                presenter.lastScaleValue = value
                                
                                //Ограничение масштабирования
                                let newScale = presenter.scale * delta
                                presenter.scale = min(max(1.0, newScale), 4.0)
                            }
                            .onEnded { _ in
                                presenter.lastScaleValue = 1.0
                                if presenter.scale <= 1.0 {
                                    withAnimation {
                                        draggingOffset = 0
                                        imageOffset = .zero
                                    }
                                }
                            }
                    )
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation {
                                    if presenter.scale > 1.0 {
                                        presenter.scale = 1.0
                                        imageOffset = .zero
                                    } else {
                                        presenter.scale = 2.0
                                    }
                                    draggingOffset = 0
                                }
                            }
                    )
                    .gesture(
                        TapGesture()
                            .onEnded {
                                withAnimation {
                                    presenter.isNavBarVisible.toggle()
                                }
                            }
                    )
                } else if viewModel.isLoading {
                    ProgressView("Загрузка...")
                } else if viewModel.error != nil {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                        Text("Не удалось загрузить изображение")
                        Button("Повторить") {
                            loadCurrentImage()
                        }
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                } else {
                    Text("Нет изображения")
                }
                
                if presenter.isNavBarVisible {
                    VStack {
                        //Навигационная панель
                        ZStack {
                            //Фон
                            Rectangle()
                                .fill(colorScheme == .dark ? 
                                      Color.black.opacity(0.7) : 
                                      Color.white.opacity(0.7))
                                .blur(radius: 3)
                                .frame(height: 60)
                                .frame(maxWidth: .infinity)
                            
                            HStack {
                                //Кнопка назад
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 18, weight: .semibold))
                                        
                                        Text("Назад")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(colorScheme == .dark ? 
                                                  Color.gray.opacity(0.3) : 
                                                  Color.gray.opacity(0.1))
                                    )
                                    .frame(height: 44)
                                }
                                
                                Spacer()
                                
                                Text("\(presenter.currentImageIndex + 1)/\(presenter.imageURLs.count)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                
                                Spacer()
                                
                                //Кнопки инструментов
                                HStack(spacing: 16) {
                                    Button(action: {
                                        shareImageURL()
                                    }) {
                                        NavBarButton(systemName: "square.and.arrow.up", colorScheme: colorScheme)
                                    }
                                    
                                    Button(action: {
                                        presenter.openInBrowser()
                                    }) {
                                        NavBarButton(systemName: "safari", colorScheme: colorScheme)
                                    }
                                }
                                .padding(.trailing, 16)
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(height: 60)
                        
                        Spacer()
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true) //Для скрытия стандартной навигационной панели
        .onAppear {
            loadCurrentImage()
        }
        .onChange(of: presenter.currentImageIndex) { _ in
            loadCurrentImage()
            imageOffset = .zero
            previewUpdateCounter += 1
        }
    }
    
    private var backgroundView: some View {
        Group {
            if colorScheme == .dark {
                Color.black
            } else {
                Color.white
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private func loadCurrentImage() {
        guard presenter.currentImageIndex >= 0,
              presenter.currentImageIndex < presenter.imageURLs.count,
              let urlString = presenter.imageURLs[presenter.currentImageIndex].url?.absoluteString else {
            return
        }
        
        viewModel.loadImage(from: urlString)
    }
    
    private func shareImageURL() {
        guard presenter.currentImageIndex >= 0,
              presenter.currentImageIndex < presenter.imageURLs.count,
              let url = presenter.imageURLs[presenter.currentImageIndex].url else {
            return
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true, completion: nil)
        }
    }
}

struct NavBarButton: View {
    let systemName: String
    let colorScheme: ColorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .fill(colorScheme == .dark ? 
                      Color.gray.opacity(0.3) : 
                      Color.gray.opacity(0.1))
                .frame(width: 36, height: 36)
            
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
    }
}

struct PreviousImageView: View {
    let imageURL: ImageURL
    let currentIndex: Int
    let updateCounter: Int 
    let geometry: GeometryProxy
    @StateObject private var viewModel = ImageViewModel()
    
    var body: some View {
        ZStack {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit) 
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    .background(
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .id("prev_\(imageURL.id)_\(currentIndex)_\(updateCounter)")
        .onAppear {
            loadImage()
        }
        .onChange(of: imageURL.id) { _ in
            loadImage()
        }
        .onChange(of: currentIndex) { _ in
            loadImage()
        }
        .onChange(of: updateCounter) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        viewModel.cancel() 
        if let urlString = imageURL.url?.absoluteString {
            viewModel.loadImage(from: urlString)
        }
    }
}

struct NextImageView: View {
    let imageURL: ImageURL
    let currentIndex: Int
    let updateCounter: Int 
    let geometry: GeometryProxy
    @StateObject private var viewModel = ImageViewModel()
    
    var body: some View {
        ZStack {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit) 
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    .background(
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .id("next_\(imageURL.id)_\(currentIndex)_\(updateCounter)")
        .onAppear {
            loadImage()
        }
        .onChange(of: imageURL.id) { _ in
            loadImage()
        }
        .onChange(of: currentIndex) { _ in
            loadImage()
        }
        .onChange(of: updateCounter) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        viewModel.cancel() 
        if let urlString = imageURL.url?.absoluteString {
            viewModel.loadImage(from: urlString)
        }
    }
} 