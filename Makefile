CWD := $(shell pwd)

.PHONY: app
app:
	emcc main.cpp -Oz --std=c++17 -o build/app.js \
		-Iopencv/build_wasm/install/include/opencv4 -Lopencv/build_wasm/install/lib \
		-Ionnxruntime/build_wasm/install/include -Lonnxruntime/build_wasm \
		-msimd128 -flto -lembind -lopencv_core -lopencv_imgproc -lopencv_dnn -lonnxruntime_webassembly \
		-s STACK_SIZE=16777216 \
		-s NO_DISABLE_EXCEPTION_CATCHING \
		-s WASM=1 \
		-s ASYNCIFY=1 \
		-s MODULARIZE=1 \
		-s EXPORT_ES6=1 \
		-s EXPORT_NAME=App \
		-s ALLOW_MEMORY_GROWTH=1 \
		-s EXPORTED_RUNTIME_METHODS=["run"] \
		--preload-file models/2d106det.ort

.PHONY: opencv
opencv:
	emcmake cmake -G Ninja \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCPU_BASELINE='' -DCPU_DISPATCH='' \
		-DCV_TRACE=OFF \
		-DENABLE_PIC=FALSE \
		-DWITH_PTHREADS_PF=OFF \
		-DCV_ENABLE_INTRINSICS=ON \
		-DWITH_PNG=OFF -DBUILD_PNG=OFF \
		-DWITH_ITT=OFF -DBUILD_ITT=OFF \
		-DWITH_TBB=OFF -DBUILD_TBB=OFF \
		-DWITH_JPEG=OFF -DBUILD_JPEG=OFF \
		-DWITH_TIFF=OFF -DBUILD_TIFF=OFF \
		-DWITH_WEBP=OFF -DBUILD_WEBP=OFF \
		-DWITH_IPP=OFF -DBUILD_IPP_IW=OFF \
		-DWITH_JASPER=OFF -DBUILD_JASPER=OFF \
		-DWITH_OPENEXR=OFF -DBUILD_OPENEXR=OFF \
		-DWITH_GTK=OFF \
		-DBUILD_ZLIB=OFF \
		-DWITH_FFMPEG=OFF \
		-DWITH_OPENGL=OFF \
		-DWITH_OPENCL=OFF \
		-DWITH_OPENVX=OFF \
		-DWITH_OPENNI=OFF \
		-DWITH_OPENNI2=OFF \
		-DWITH_GTK_2_X=OFF \
		-DWITH_GSTREAMER=OFF \
		-DWITH_OPENCL_SVM=OFF \
		-DWITH_OPENCLAMDFFT=OFF \
		-DWITH_OPENCLAMDBLAS=OFF \
		-DWITH_ADE=OFF \
		-DWITH_V4L=OFF \
		-DWITH_VTK=OFF \
		-DWITH_1394=OFF \
		-DWITH_EIGEN=OFF \
		-DWITH_QUIRC=OFF \
		-DWITH_LAPACK=OFF \
		-DWITH_GPHOTO2=OFF \
		-DBUILD_DOCS=OFF \
		-DBUILD_TESTS=OFF \
		-DBUILD_PACKAGE=OFF \
		-DBUILD_EXAMPLES=OFF \
		-DBUILD_PERF_TESTS=OFF \
		-DBUILD_SHARED_LIBS=OFF \
		-DBUILD_LIST=core,imgproc,dnn \
		-DCMAKE_C_FLAGS="-msimd128 -s USE_PTHREADS=0 -s DISABLE_EXCEPTION_CATCHING" \
		-DCMAKE_CXX_FLAGS="-msimd128 -s USE_PTHREADS=0 -s DISABLE_EXCEPTION_CATCHING" \
		opencv/CMakeLists.txt \
		-B opencv/build_wasm && \
		ninja -C opencv/build_wasm && ninja -C opencv/build_wasm install
	
.PHONY: onnxruntime
onnxruntime:
	./venv/bin/python onnxruntime/tools/ci_build/reduce_op_kernels.py \
		--enable_type_reduction \
		--cmake_build_dir=onnxruntime/build_wasm \
		models/required_operators_and_types.config && \
	emcmake cmake -G Ninja \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCMAKE_INSTALL_PREFIX=${CWD}/onnxruntime/build_wasm/install \
		-DPython_EXECUTABLE=${CWD}/venv/bin/python \
		-DPYTHON_EXECUTABLE=${CWD}/venv/bin/python \
		-Donnxruntime_DISABLE_RTTI=ON \
		-Donnxruntime_MINIMAL_BUILD=ON \
		-Donnxruntime_REDUCED_OPS_BUILD=ON \
		-Donnxruntime_BUILD_UNIT_TESTS=OFF \
		-Donnxruntime_DISABLE_EXCEPTIONS=ON \
		-Donnxruntime_ENABLE_WEBASSEMBLY_SIMD=ON \
		-Donnxruntime_ENABLE_WEBASSEMBLY_THREADS=OFF \
		-Donnxruntime_BUILD_WEBASSEMBLY_STATIC_LIB=ON \
		-Donnxruntime_ENABLE_WEBASSEMBLY_EXCEPTION_THROWING=OFF \
		-Donnxruntime_ENABLE_WEBASSEMBLY_EXCEPTION_CATCHING=OFF \
		onnxruntime/cmake/CMakeLists.txt \
		-B onnxruntime/build_wasm && \
		ninja -C onnxruntime/build_wasm && ninja -C onnxruntime/build_wasm install
