#include <vector>
#include <optional>
#include <iostream>
#include <emscripten/bind.h>
#include <opencv2/opencv.hpp>
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>

class App {
public:
    static App& get() {
        static App instance;
        return instance;
    }

    App(): _memory_info(Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault)) {
        _options.AddConfigEntry("session.load_model_format", "ORT");
        _session = Ort::Session(_env, "models/2d106det.ort", _options);
        auto input_count = _session.value().GetInputCount();
        assert(input_count == 1);
        for (size_t i = 0; i < input_count; ++i) {
            auto name = _session.value().GetInputNameAllocated(i, allocator);
            _input_names_allocated.push_back(std::move(name));
            _input_names.push_back(_input_names_allocated.back().get());
            auto info = _session.value().GetInputTypeInfo(i).GetTensorTypeAndShapeInfo();
            _shape = info.GetShape();
            for (int64_t &size : _shape) {
                if (size < 0) {
                    size = -size;
                }
            }
            std::cout << "Input " << i << ": ";
            for (auto x : _shape) {
                std::cout << x << ' ';
            }
            std::cout << std::endl;
        }

        auto output_count = _session.value().GetOutputCount();
        assert(output_count == 1);
        for (size_t i = 0; i < output_count; ++i) {
            auto name = _session.value().GetOutputNameAllocated(i, allocator);
            _output_names_allocated.push_back(std::move(name));
            _output_names.push_back(_output_names_allocated.back().get());
        }
    }

    std::vector<float> run(std::vector<float> data) {
        const auto input_tensor = Ort::Value::CreateTensor<float>(_memory_info, data.data(), data.size(), _shape.data(), _shape.size());
        auto outputs = _session.value().Run(_run_options, _input_names.data(), &input_tensor, 1, _output_names.data(), _output_names.size());
        auto result = outputs.at(0).GetTensorData<float>();
        auto count = outputs.at(0).GetTensorTypeAndShapeInfo().GetElementCount();
        return std::vector<float>(result, result + count);
    }

private:
    Ort::Env _env;
    std::vector<int64_t> _shape;
    Ort::SessionOptions _options;
    Ort::RunOptions _run_options;
    Ort::MemoryInfo _memory_info;
    std::optional<Ort::Session> _session;
    std::vector<const char *> _input_names;
    std::vector<const char *> _output_names;
    Ort::AllocatorWithDefaultOptions allocator;
    std::vector<Ort::AllocatedStringPtr> _input_names_allocated;
    std::vector<Ort::AllocatedStringPtr> _output_names_allocated;
};

EMSCRIPTEN_KEEPALIVE
emscripten::val run(emscripten::val bitmap, int width, int height) {
    App &app = App::get();
    std::vector<uint8_t> image_bytes_rgba = emscripten::vecFromJSArray<uint8_t>(bitmap);
    cv::Mat image_rgba(height, width, CV_8UC4, image_bytes_rgba.data());
    cv::Mat image_bgr;
    std::cout << "Image: " << width << ' ' << height << std::endl;
    cv::cvtColor(image_rgba, image_bgr, cv::COLOR_RGBA2BGR);
    cv::Mat image;
    cv::dnn::blobFromImage(image_bgr, image);
    std::cout << "Blob: " << image.size[0] << ' ' << image.size[1] << ' ' << image.size[2] << ' ' << image.size[3] << std::endl;
    std::vector<float> data((float *)image.datastart, (float *)image.dataend);
    std::vector<float> output = app.run(data);
    for (size_t i = 0; i < output.size() / 2; ++i) {
        cv::Point2f point(
            (int)((output[i * 2 + 0] + 1.0) / 2.0 * width),
            (int)((output[i * 2 + 1] + 1.0) / 2.0 * height)
        );
        cv::circle(image_rgba, point, 1, cv::Scalar(0, 255, 0, 255), cv::FILLED);
    }
    std::vector<uint8_t> result(image_rgba.dataend - image_rgba.datastart);
    image_rgba.reshape(1, 1).copyTo(result);
    return emscripten::val(emscripten::typed_memory_view(result.size(), result.data()));
}

EMSCRIPTEN_BINDINGS(faceswap) {
    emscripten::function("run", &run);
}