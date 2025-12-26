/* @refresh reload */
import { render } from "solid-js/web";
import "./index.css";
import Triangle from "./triangle.tsx";
import Cube from "./cube.tsx";

const root = document.getElementById("root");
if (!root) throw new Error("Root element not found");
render(() => <App />, root);

function App() {
	return (
		<div>
			<Triangle />
			<Cube />
		</div>
	);
}
