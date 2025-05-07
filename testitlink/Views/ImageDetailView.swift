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
    
    //Состояние анимации перелистывания
    @State private var isAnimatingPage = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleNavBarIfNotZoomed()
                    }
                
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
                            .opacity(draggingOffset > 0 ? min(draggingOffset / 100, 1.0) : 0)
                            .offset(x: -geometry.size.width + max(0, draggingOffset))
                            .zIndex(draggingOffset > 0 ? 1 : 0)
                        }
                        
                        //Текущее изображение
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(presenter.scale)
                            .offset(x: presenter.scale <= 1.0 ? draggingOffset : imageOffset.width + dragOffset.width, 
                                    y: presenter.scale <= 1.0 ? 0 : imageOffset.height + dragOffset.height)
                            .zIndex(1)
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
                                            let threshold: CGFloat = 60
                                            let velocity = value.predictedEndLocation.x - value.location.x
                                            let isPaging = abs(draggingOffset) > threshold || abs(velocity) > 100
                                            
                                            if isPaging {
                                                isAnimatingPage = true
                                                
                                                let isNext = draggingOffset < 0 || velocity < -100
                                                
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    if !isNext {
                                                        draggingOffset = geometry.size.width
                                                    } else {
                                                        draggingOffset = -geometry.size.width
                                                    }
                                                }
                                                
                                                //Чуть чуть костыльно, позаимствовал из своего старого пет проекта, ток потом увидел, мало времени на нормальное решение, но визуально выглядит даже не как костыль
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                                    if !isNext {
                                                        presenter.previousImage()
                                                    } else {
                                                        presenter.nextImage()
                                                    }
                                                    
                                                    previewUpdateCounter += 1
                                                    
                                                    draggingOffset = 0
                                                    
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                        isAnimatingPage = false
                                                    }
                                                }
                                            } else {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    draggingOffset = 0
                                                }
                                            }
                                        }
                                    }
                            )
                            .onTapGesture {
                                toggleNavBarIfNotZoomed()
                            }
                        
                        if presenter.scale <= 1.0 && presenter.imageURLs.count > 1 {
                            let nextIndex = (presenter.currentImageIndex + 1) % presenter.imageURLs.count
                            NextImageView(
                                imageURL: presenter.imageURLs[nextIndex],
                                currentIndex: presenter.currentImageIndex,
                                updateCounter: previewUpdateCounter,
                                geometry: geometry
                            )
                            .opacity(draggingOffset < 0 ? min(-draggingOffset / 100, 1.0) : 0)
                            .offset(x: geometry.size.width + min(0, draggingOffset))
                            .zIndex(draggingOffset < 0 ? 1 : 0)
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
                    .disabled(isAnimatingPage)
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
                    VStack(spacing: 0) {
                        //Навигационная панель
                        ZStack(alignment: .bottom) {
                            //Фон, который тянется до верха экрана
                            Rectangle()
                                .fill(colorScheme == .dark ? 
                                      Color.black.opacity(0.7) : 
                                      Color.white.opacity(0.7))
                                .blur(radius: 3)
                                .frame(maxWidth: .infinity)
                                .edgesIgnoringSafeArea(.top)
                            
                            //Контент бара
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
                            .frame(height: 60)
                            .padding(.bottom, 0)
                        }
                        .frame(height: 60 + safeAreaInsets().top)
                        .padding(.top, 0)
                        
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
    
    //Безопасные отступы для устройства
    private func safeAreaInsets() -> EdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            //Значения по умолчанию
            return EdgeInsets(top: 47, leading: 0, bottom: 0, trailing: 0)
        }
        
        let insets = window.safeAreaInsets
        return EdgeInsets(
            top: max(47, insets.top),
            leading: insets.left,
            bottom: insets.bottom,
            trailing: insets.right
        )
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
    
    
    private func toggleNavBarIfNotZoomed() {
        if presenter.scale <= 1.0 {
            withAnimation {
                presenter.isNavBarVisible.toggle()
            }
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
