import { createEffect, createSignal } from "solid-js";

import { mat4, vec3 } from "wgpu-matrix";

import { quitIfWebGPUNotAvailable } from "./util";

export default function Cube() {
	const [canvas, setCanvas] = createSignal<HTMLCanvasElement | null>(null);

	let aspect: number | null = null;
	let projectionMatrix: Float32Array | null = null;

	const modelMatrix1 = mat4.translation(vec3.create(-2, 0, 0));
	const modelMatrix2 = mat4.translation(vec3.create(2, 0, 0));
	const modelViewProjectionMatrix1 = mat4.create();
	const modelViewProjectionMatrix2 = mat4.create();
	const viewMatrix = mat4.translation(vec3.fromValues(0, 0, -7));

	const tmpMat41 = mat4.create();
	const tmpMat42 = mat4.create();

	const matrixSize = 4 * 16; // 4x4 matrix
	const offset = 256; // uniformBindGroup offset must be 256-byte aligned
	const uniformBufferSize = offset + matrixSize;

	createEffect(() => {
		const c = canvas();
		if (!c) return;
		setupWebGPU(c);
	});

	async function setupWebGPU(canvas: HTMLCanvasElement) {
		const adapter = await navigator.gpu?.requestAdapter({
			featureLevel: "compatibility",
		});
		const device = await adapter?.requestDevice();
		if (!device) return;

		quitIfWebGPUNotAvailable(adapter, device);

		const context = canvas.getContext("webgpu");
		if (!context) return;

		const devicePixelRatio = window.devicePixelRatio;
		canvas.width = canvas.clientWidth * devicePixelRatio;
		canvas.height = canvas.clientHeight * devicePixelRatio;
		const presentationFormat = navigator.gpu.getPreferredCanvasFormat();

		aspect = canvas.width / canvas.height;
		projectionMatrix = mat4.perspective(
			(2 * Math.PI) / 5,
			aspect,
			1,
			100.0,
		) as Float32Array;

		context.configure({
			device,
			format: presentationFormat,
		});

		// Create a vertex buffer from the cube data.
		const verticesBuffer = device.createBuffer({
			size: cubeVertexArray.byteLength,
			usage: GPUBufferUsage.VERTEX,
			mappedAtCreation: true,
		});
		new Float32Array(verticesBuffer.getMappedRange()).set(cubeVertexArray);
		verticesBuffer.unmap();

		const pipeline = device.createRenderPipeline({
			layout: "auto",
			vertex: {
				module: device.createShaderModule({
					code: cubeVertWGSL,
				}),
				buffers: [
					{
						arrayStride: cubeVertexSize,
						attributes: [
							{
								// position
								shaderLocation: 0,
								offset: cubePositionOffset,
								format: "float32x4",
							},
							{
								// uv
								shaderLocation: 1,
								offset: cubeUVOffset,
								format: "float32x2",
							},
						],
					},
				],
			},
			fragment: {
				module: device.createShaderModule({
					code: cubeFragWGSL,
				}),
				targets: [
					{
						format: presentationFormat,
					},
				],
			},
			primitive: {
				topology: "triangle-list",

				// Backface culling since the cube is solid piece of geometry.
				// Faces pointing away from the camera will be occluded by faces
				// pointing toward the camera.
				cullMode: "back",
			},

			// Enable depth testing so that the fragment closest to the camera
			// is rendered in front.
			depthStencil: {
				depthWriteEnabled: true,
				depthCompare: "less",
				format: "depth24plus",
			},
		});

		const depthTexture = device.createTexture({
			size: [canvas.width, canvas.height],
			format: "depth24plus",
			usage: GPUTextureUsage.RENDER_ATTACHMENT,
		});

		const uniformBuffer = device.createBuffer({
			size: uniformBufferSize,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const uniformBindGroup1 = device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: [
				{
					binding: 0,
					resource: {
						buffer: uniformBuffer,
						offset: 0,
						size: matrixSize,
					},
				},
			],
		});

		const uniformBindGroup2 = device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: [
				{
					binding: 0,
					resource: {
						buffer: uniformBuffer,
						offset: offset,
						size: matrixSize,
					},
				},
			],
		});

		const renderPassDescriptor: GPURenderPassDescriptor = {
			colorAttachments: [
				{
					view: null as unknown as GPUTextureView, // Assigned later

					clearValue: [0.5, 0.5, 0.5, 1.0],
					loadOp: "clear",
					storeOp: "store",
				},
			],
			depthStencilAttachment: {
				view: depthTexture.createView(),

				depthClearValue: 1.0,
				depthLoadOp: "clear",
				depthStoreOp: "store",
			},
		};

		requestAnimationFrame(() =>
			frame(
				uniformBuffer,
				renderPassDescriptor,
				pipeline,
				verticesBuffer,
				context,
				device,
				uniformBindGroup1,
				uniformBindGroup2,
			),
		);
	}

	function frame(
		uniformBuffer: GPUBuffer,
		renderPassDescriptor: GPURenderPassDescriptor,
		pipeline: GPURenderPipeline,
		verticesBuffer: GPUBuffer,
		context: GPUCanvasContext,
		device: GPUDevice,
		uniformBindGroup1: GPUBindGroup,
		uniformBindGroup2: GPUBindGroup,
	) {
		updateTransformationMatrix(
			modelMatrix1,
			modelMatrix2,
			modelViewProjectionMatrix1,
			modelViewProjectionMatrix2,
			viewMatrix,
			tmpMat41,
			tmpMat42,
		);
		device.queue.writeBuffer(
			uniformBuffer,
			0,
			modelViewProjectionMatrix1.buffer,
			modelViewProjectionMatrix1.byteOffset,
			modelViewProjectionMatrix1.byteLength,
		);
		device.queue.writeBuffer(
			uniformBuffer,
			offset,
			modelViewProjectionMatrix2.buffer,
			modelViewProjectionMatrix2.byteOffset,
			modelViewProjectionMatrix2.byteLength,
		);

		(
			renderPassDescriptor.colorAttachments as GPURenderPassColorAttachment[]
		)[0].view = context.getCurrentTexture().createView();

		const commandEncoder = device.createCommandEncoder();
		const passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor);
		passEncoder.setPipeline(pipeline);
		passEncoder.setVertexBuffer(0, verticesBuffer);

		// Bind the bind group (with the transformation matrix) for
		// each cube, and draw.
		passEncoder.setBindGroup(0, uniformBindGroup1);
		passEncoder.draw(cubeVertexCount);

		passEncoder.setBindGroup(0, uniformBindGroup2);
		passEncoder.draw(cubeVertexCount);

		passEncoder.end();
		device.queue.submit([commandEncoder.finish()]);

		requestAnimationFrame(() =>
			frame(
				uniformBuffer,
				renderPassDescriptor,
				pipeline,
				verticesBuffer,
				context,
				device,
				uniformBindGroup1,
				uniformBindGroup2,
			),
		);
	}

	function updateTransformationMatrix(
		modelMatrix1: Float32Array,
		modelMatrix2: Float32Array,
		modelViewProjectionMatrix1: Float32Array,
		modelViewProjectionMatrix2: Float32Array,
		viewMatrix: Float32Array,
		tmpMat41: Float32Array,
		tmpMat42: Float32Array,
	) {
		const now = Date.now() / 1000;

		mat4.rotate(
			modelMatrix1,
			vec3.fromValues(Math.sin(now), Math.cos(now), 0),
			1,
			tmpMat41,
		);
		mat4.rotate(
			modelMatrix2,
			vec3.fromValues(Math.cos(now), Math.sin(now), 0),
			1,
			tmpMat42,
		);

		mat4.multiply(viewMatrix, tmpMat41, modelViewProjectionMatrix1);
		mat4.multiply(
			projectionMatrix as Float32Array,
			modelViewProjectionMatrix1,
			modelViewProjectionMatrix1,
		);
		mat4.multiply(viewMatrix, tmpMat42, modelViewProjectionMatrix2);
		mat4.multiply(
			projectionMatrix as Float32Array,
			modelViewProjectionMatrix2,
			modelViewProjectionMatrix2,
		);
	}

	return <canvas width={300} height={300} ref={setCanvas} />;
}

const cubeFragWGSL = `
@fragment
fn main(
    @location(0) fragUV: vec2f,
    @location(1) fragPosition: vec4f
) -> @location(0) vec4f {
    return fragPosition;
}
`;

const cubeVertWGSL = `
struct Uniforms {
    modelViewProjectionMatrix : mat4x4f,
}
@binding(0) @group(0) var<uniform> uniforms : Uniforms;

struct VertexOutput {
    @builtin(position) Position : vec4f,
    @location(0) fragUV : vec2f,
    @location(1) fragPosition: vec4f,
}

@vertex
fn main(
    @location(0) position : vec4f,
    @location(1) uv : vec2f
) -> VertexOutput {
    var output : VertexOutput;
    output.Position = uniforms.modelViewProjectionMatrix * position;
    output.fragUV = uv;
    output.fragPosition = 0.5 * (position + vec4(1.0, 1.0, 1.0, 1.0));
    return output;
}
`;

export const cubeVertexSize = 4 * 10; // Byte size of one cube vertex.
export const cubePositionOffset = 0;
export const cubeColorOffset = 4 * 4; // Byte offset of cube vertex color attribute.
export const cubeUVOffset = 4 * 8;
export const cubeVertexCount = 36;

// prettier-ignore
export const cubeVertexArray = new Float32Array([
	// float4 position, float4 color, float2 uv,
	1, -1, 1, 1, 1, 0, 1, 1, 0, 1, -1, -1, 1, 1, 0, 0, 1, 1, 1, 1, -1, -1, -1, 1,
	0, 0, 0, 1, 1, 0, 1, -1, -1, 1, 1, 0, 0, 1, 0, 0, 1, -1, 1, 1, 1, 0, 1, 1, 0,
	1, -1, -1, -1, 1, 0, 0, 0, 1, 1, 0,

	1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, -1, 1, 1, 1, 0, 1, 1, 1, 1, 1, -1, -1, 1, 1,
	0, 0, 1, 1, 0, 1, 1, -1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1,
	-1, -1, 1, 1, 0, 0, 1, 1, 0,

	-1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, 1, 1,
	1, 0, 1, 1, 0, -1, 1, -1, 1, 0, 1, 0, 1, 0, 0, -1, 1, 1, 1, 0, 1, 1, 1, 0, 1,
	1, 1, -1, 1, 1, 1, 0, 1, 1, 0,

	-1, -1, 1, 1, 0, 0, 1, 1, 0, 1, -1, 1, 1, 1, 0, 1, 1, 1, 1, 1, -1, 1, -1, 1,
	0, 1, 0, 1, 1, 0, -1, -1, -1, 1, 0, 0, 0, 1, 0, 0, -1, -1, 1, 1, 0, 0, 1, 1,
	0, 1, -1, 1, -1, 1, 0, 1, 0, 1, 1, 0,

	1, 1, 1, 1, 1, 1, 1, 1, 0, 1, -1, 1, 1, 1, 0, 1, 1, 1, 1, 1, -1, -1, 1, 1, 0,
	0, 1, 1, 1, 0, -1, -1, 1, 1, 0, 0, 1, 1, 1, 0, 1, -1, 1, 1, 1, 0, 1, 1, 0, 0,
	1, 1, 1, 1, 1, 1, 1, 1, 0, 1,

	1, -1, -1, 1, 1, 0, 0, 1, 0, 1, -1, -1, -1, 1, 0, 0, 0, 1, 1, 1, -1, 1, -1, 1,
	0, 1, 0, 1, 1, 0, 1, 1, -1, 1, 1, 1, 0, 1, 0, 0, 1, -1, -1, 1, 1, 0, 0, 1, 0,
	1, -1, 1, -1, 1, 0, 1, 0, 1, 1, 0,
]);
