import Foundation

/// Calls `onChange` on the main queue whenever the file changes on disk.
/// Survives "atomic" saves, where editors replace the file instead of writing into it.
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var retries = 0

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        start(notify: false)
    }

    deinit {
        source?.cancel()
    }

    private func start(notify: Bool) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // The file is being replaced; try again shortly, then give up.
            guard retries < 20 else { return }
            retries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.start(notify: true)
            }
            return
        }
        retries = 0

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self, let source = self.source else { return }
            if !source.data.isDisjoint(with: [.delete, .rename]) {
                source.cancel()
                self.source = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.start(notify: true)
                }
            } else {
                self.onChange()
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source

        if notify { onChange() }
    }
}
